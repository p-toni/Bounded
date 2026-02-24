# frozen_string_literal: true

require "digest"
require "json"

module Workflows
  class Gateway
    def initialize(workflow_run_id:)
      @workflow_run = WorkflowRun.find(workflow_run_id)
    end

    def run
      workflow_run.with_lock do
        return cancel_run! if workflow_run.cancel_requested_at.present?

        workflow_run.update!(status: "running") if workflow_run.status == "queued"
        publish_event("run.accepted", { status: workflow_run.status }) if workflow_run.workflow_step_events.empty?

        execute_next_step!
      end
    rescue StandardError => e
      workflow_run.update!(status: "failed", error_json: { message: e.message })
      publish_event("run.failed", { error: e.message })
      raise
    end

    private

    attr_reader :workflow_run

    def execute_next_step!
      steps = definition.steps
      step_index = workflow_run.agent_run_state_json.fetch("step_index", 0).to_i
      if step_index >= steps.length
        workflow_run.update!(status: "succeeded")
        publish_event("run.completed", { status: "succeeded" })
        return
      end

      step = steps[step_index]
      step_idempotency_key = "#{step}:#{step_index}"
      if WorkflowStepEvent.exists?(
        workflow_run_id: workflow_run.id,
        step_name: step.to_s,
        step_status: "completed",
        step_idempotency_key: step_idempotency_key
      )
        next_state = workflow_run.agent_run_state_json.merge("step_index" => step_index + 1, "idempotent_skip" => step.to_s)
        workflow_run.update!(agent_run_state_json: next_state)
        publish_event("step.delta", { step: step, skipped: true, reason: "idempotent_replay" })
        if step_index + 1 >= steps.length
          workflow_run.update!(status: "succeeded")
          publish_event("run.completed", { status: "succeeded" })
        else
          self.class.enqueue(workflow_run.id)
        end
        return
      end

      emit_step(:started, step, {})
      result = send(step)

      if result.is_a?(Hash) && result[:waiting_for_input]
        workflow_run.update!(status: "waiting_for_input", agent_run_state_json: workflow_run.agent_run_state_json.merge("pending_step" => step.to_s))
        emit_step(:waiting_for_input, step, result)
        publish_event("run.waiting_for_input", result)
        return
      end

      next_state = workflow_run.agent_run_state_json.merge("step_index" => step_index + 1, "last_output" => result || {})
      workflow_run.update!(agent_run_state_json: next_state)
      emit_step(:completed, step, result || {})
      publish_event("step.completed", { step: step, step_index: step_index + 1, total_steps: steps.length })

      if step_index + 1 >= steps.length
        workflow_run.update!(status: "succeeded")
        publish_event("run.completed", { status: "succeeded" })
      else
        self.class.enqueue(workflow_run.id)
      end
    end

    def definition
      @definition ||= case workflow_run.workflow_type
                      when "prepare_rep" then Workflows::Definitions::PrepareRep.new(workflow_run)
                      when "run_reality_audit" then Workflows::Definitions::RunRealityAudit.new(workflow_run)
                      when "post_session_debrief" then Workflows::Definitions::PostSessionDebrief.new(workflow_run)
                      when "evidence_assist" then Workflows::Definitions::EvidenceAssist.new(workflow_run)
                      when "render_share_pack" then Workflows::Definitions::RenderSharePack.new(workflow_run)
                      else
                        raise ArgumentError, "Unknown workflow type: #{workflow_run.workflow_type}"
                      end
    end

    def emit_step(status, step_name, output_json)
      input_json = workflow_run.input_json || {}
      step_idempotency_key = if status.to_s == "completed"
                               "#{step_name}:#{workflow_run.agent_run_state_json.fetch('step_index', 0)}"
                             end
      step_event = WorkflowStepEvent.create!(
        workflow_run_id: workflow_run.id,
        step_name: step_name.to_s,
        step_status: status.to_s,
        tool_name: nil,
        input_json: input_json,
        output_json: output_json,
        bound_versions_json: workflow_run.bound_versions_json || {},
        input_hash: sha(input_json),
        output_hash: sha(output_json),
        tool_schema_version: workflow_run.bound_versions_json.fetch("schema_version", "1.0.0"),
        step_idempotency_key: step_idempotency_key,
        started_at: Time.current,
        finished_at: Time.current,
        schema_version: "1.0.0"
      )
      Schemas::Validator.call!(schema_name: "workflow_step_event", payload: step_event.attributes)
    end

    def publish_event(event_type, payload)
      event_seq = workflow_run.workflow_step_events.count + 1
      event = Protocol::EventBuilder.build(run: workflow_run, event_seq: event_seq, event_type: event_type, payload: payload)
      Protocol::Streamer.publish!(run: workflow_run, event: event)
    end

    def cancel_run!
      workflow_run.update!(status: "canceled")
      publish_event("run.canceled", { reason: "cancel_requested" })
    end

    def resolve_topic
      topic_id = workflow_run.input_json["topic_id"]
      queue = topic_id ? nil : Workflows::ScheduleQueue.call(user_id: workflow_run.user_id)
      queued_topic_id = queue && (queue[:selected_topic_id] || queue["selected_topic_id"])
      ranked_topics = queue && (queue[:queue] || queue["queue"])
      fallback_ranked_topic_id = ranked_topics&.first&.dig(:topic_id) || ranked_topics&.first&.dig("topic_id")
      topic = if topic_id
                Topic.find(topic_id)
              elsif queued_topic_id.present?
                Topic.find_by(id: queued_topic_id)
              elsif fallback_ranked_topic_id.present?
                Topic.find_by(id: fallback_ranked_topic_id)
              else
                Topic.where(user_id: workflow_run.user_id).order(updated_at: :desc).first
              end
      raise "No topic found for prepare_rep" unless topic

      state_delta = { "topic_id" => topic.id }
      state_delta["topic_queue"] = json_copy(queue) if queue
      merge_state!(state_delta)
      selected_by = if topic_id.present?
                      "input"
                    elsif queued_topic_id.present?
                      "schedule_queue"
                    elsif fallback_ranked_topic_id.present?
                      "schedule_queue_fallback"
                    else
                      "fallback_recent"
                    end
      { topic_id: topic.id, selected_by: selected_by }
    end

    def load_latest_versions
      topic = Topic.find(workflow_run.agent_run_state_json.fetch("topic_id"))
      graph_version = topic.graph_versions.order(version_int: :desc).first
      source_version = topic.source&.source_versions&.order(created_at: :desc)&.first
      raise "Missing graph/source version" unless graph_version && source_version

      merge_bound_versions!(
        "graph_version_id" => graph_version.id,
        "source_version_id" => source_version.id,
        "rubric_version_id" => RubricVersion.order(created_at: :desc).pick(:id)
      )
      { graph_version_id: graph_version.id, source_version_id: source_version.id }
    end

    def validate_anchor_evidence
      graph_version_id = workflow_run.bound_versions_json.fetch("graph_version_id")
      edges = Edge.where(graph_version_id: graph_version_id)
      evidences = EdgeEvidence.where(edge_id: edges.map(&:id))
      result = Workflows::EngineBridge.validate_anchor_evidence(graph_edges: edges.map(&:attributes), edge_evidences: evidences.map(&:attributes))
      return { waiting_for_input: true, reason: "missing_anchor_evidence", errors: result[:errors] } unless result[:ok]

      granularity = Workflows::GraphGranularity.validate(graph_version: GraphVersion.find(graph_version_id))
      return { waiting_for_input: true, reason: "graph_granularity_violation", errors: granularity[:errors], stats: granularity[:stats] } unless granularity[:ok]

      result.merge(granularity: granularity[:stats])
    end

    def generate_drill_instances
      topic_id = workflow_run.agent_run_state_json.fetch("topic_id")
      graph_version_id = workflow_run.bound_versions_json.fetch("graph_version_id")
      source_version_id = workflow_run.bound_versions_json.fetch("source_version_id")
      topic = Topic.find(topic_id)
      graph_version = GraphVersion.find(graph_version_id)

      nodes = Node.where(graph_version_id: graph_version_id).order(:id)
      edges = Edge.where(graph_version_id: graph_version_id).order(:id)
      anchor_edges = edges.select(&:is_anchor)
      anchor_edge_ids = anchor_edges.map { |e| e.edge_id.presence || e.id }
      anchor_node_ids = anchor_edges.flat_map { |e| [e.from_node_id, e.to_node_id] }.compact.uniq
      downstream_by_edge_id = edges.each_with_object({}) do |edge, memo|
        primary_id = edge.edge_id.presence || edge.id
        memo[primary_id] = [edge.to_node_id].compact
      end

      rotation_policy = Workflows::RotationPolicy.call(
        user_id: workflow_run.user_id,
        topic: topic,
        graph_version: graph_version
      )

      schedule = Schedule.find_or_initialize_by(user_id: workflow_run.user_id)
      schedule.state_json = rotation_policy.fetch(:schedule_state)
      schedule.schema_version ||= "1.0.0"
      schedule.save!

      audit_target = if rotation_policy[:audit_required] && rotation_policy[:audit_target_edge_id].present?
                       Edge.find_by(id: rotation_policy[:audit_target_edge_id])
                     end
      candidate_spans = SourceSpan.where(source_version_id: source_version_id).order(:ordinal).limit(12).pluck(:id)
      correct_span_ids = if audit_target
                           EdgeEvidence.where(edge_id: audit_target.id).limit(3).pluck(:source_span_id)
                         else
                           []
                         end
      correct_span_ids = candidate_spans.first([2, candidate_spans.length].min) if correct_span_ids.empty?

      context = {
        user_id: workflow_run.user_id,
        topic_id: topic_id,
        graph_version_id: graph_version_id,
        source_version_id: source_version_id,
        nodes: nodes.map(&:attributes),
        edges: edges.map(&:attributes),
        anchor_node_ids: anchor_node_ids,
        anchor_edge_ids: anchor_edge_ids,
        predict_choices: edges.map { |e| "pred_#{e.edge_id.presence || e.id}" }.first(5),
        invariant_choices: nodes.map { |n| "inv_#{n.node_id.presence || n.id}" }.first(6),
        repair_choices: edges.map { |e| "repair_#{e.edge_id.presence || e.id}" }.first(6),
        downstream_by_edge_id: downstream_by_edge_id,
        candidate_spans: candidate_spans,
        correct_span_ids: correct_span_ids,
        answer_keys: {}
      }
      generated = Workflows::EngineBridge.generate_session_pack(
        topic_ctx: context,
        rotation: rotation_policy.fetch(:diagnostics),
        rubric_version_id: workflow_run.bound_versions_json.fetch("rubric_version_id")
      )
      merge_state!(
        "rotation_policy" => {
          diagnostics: rotation_policy[:diagnostics],
          audit_required: rotation_policy[:audit_required],
          audit_reason: rotation_policy[:audit_reason],
          audit_target_edge_id: rotation_policy[:audit_target_edge_id]
        },
        "schedule_id" => schedule.id,
        "generated_session_pack" => generated[:session_pack],
        "generated_drill_instances" => generated[:drill_instances]
      )
      generated
    end

    def persist_session_pack
      state = workflow_run.agent_run_state_json
      drills = Array(state["generated_drill_instances"])
      created = drills.map do |dr|
        attrs = normalize_payload(dr)
        lookup = attrs.slice("topic_id", "graph_version_id", "rubric_version_id", "diagnostic", "seed")
        record = DrillInstance.find_or_initialize_by(lookup)
        record.assign_attributes(attrs.except("id", "created_at", "updated_at"))
        record.save! if record.new_record? || record.changed?
        record
      end

      session_pack_data = normalize_payload(state["generated_session_pack"])
      session_pack_attrs = if session_pack_data.is_a?(Hash)
                             session_pack_data.merge("drill_instance_ids" => created.map(&:id))
                           else
                             {
        user_id: workflow_run.user_id,
        topic_id: workflow_run.agent_run_state_json.fetch("topic_id"),
        graph_version_id: workflow_run.bound_versions_json.fetch("graph_version_id"),
        source_version_id: workflow_run.bound_versions_json.fetch("source_version_id"),
        rubric_version_id: workflow_run.bound_versions_json.fetch("rubric_version_id"),
        drill_instance_ids: created.map(&:id),
        schema_version: "1.0.0",
        created_at: Time.current
      }
                           end
      session_pack_attrs = session_pack_attrs.except("id", "created_at", "updated_at")
      pack = SessionPack.create!(session_pack_attrs)
      { session_pack_id: pack.id, drill_instance_ids: created.map(&:id) }
    end

    def create_audit_drill_instance
      topic_id = workflow_run.input_json.fetch("topic_id")
      edge_id = workflow_run.input_json.fetch("edge_id")
      topic = Topic.find(topic_id)
      graph_version = topic.graph_versions.order(version_int: :desc).first
      source_version = topic.source.source_versions.order(created_at: :desc).first
      rubric = RubricVersion.order(created_at: :desc).first
      edge = Edge.find(edge_id)
      candidates = SourceSpan.where(source_version_id: source_version.id).order(:ordinal).limit(6).pluck(:id)
      correct = EdgeEvidence.where(edge_id: edge.id).limit(2).pluck(:source_span_id)

      dr = Workflows::EngineBridge.generate_audit_instance(
        topic_ctx: {
          topic_id: topic.id,
          graph_version_id: graph_version.id,
          source_version_id: source_version.id,
          rubric_version_id: rubric.id,
          candidate_spans: candidates,
          correct_span_ids: correct
        },
        target_edge_id: edge.id
      )
      created = DrillInstance.create!(normalize_payload(dr))
      merge_state!("audit_drill_instance_id" => created.id, "audit_edge_id" => edge.id)
      { drill_instance_id: created.id }
    end

    def wait_for_audit_input
      delta = workflow_run.agent_run_state_json["input_delta"]
      return { waiting_for_input: true, reason: "audit_answer_required", drill_instance_id: workflow_run.agent_run_state_json["audit_drill_instance_id"] } if delta.blank?

      { accepted: true }
    end

    def create_audit_attempt
      delta = workflow_run.agent_run_state_json.fetch("input_delta")
      drill = DrillInstance.find(workflow_run.agent_run_state_json.fetch("audit_drill_instance_id"))
      topic = Topic.find(drill.topic_id)
      attempt = Attempt.find_or_initialize_by(user_id: workflow_run.user_id, drill_instance_id: drill.id)
      if attempt.persisted?
        same_payload = attempt.answer_json == delta && attempt.source_opened_bool == !!delta["source_opened_bool"]
        raise "Existing audit attempt has different payload" unless same_payload
      end
      attempt.assign_attributes(
        topic_id: topic.id,
        graph_version_id: drill.graph_version_id,
        source_version_id: drill.source_version_id,
        rubric_version_id: drill.rubric_version_id,
        diagnostic: drill.diagnostic,
        answer_json: delta,
        duration_ms: delta["duration_ms"] || 0,
        source_opened_bool: !!delta["source_opened_bool"],
        schema_version: "1.0.0"
      )
      attempt.save! if attempt.new_record? || attempt.changed?
      merge_state!("audit_attempt_id" => attempt.id)
      { attempt_id: attempt.id }
    end

    def compute_audit_score
      attempt = Attempt.find(workflow_run.agent_run_state_json.fetch("audit_attempt_id"))
      drill = DrillInstance.find(attempt.drill_instance_id)
      result = Workflows::EngineBridge.compute_score(
        "attempt" => attempt.attributes,
        "drill_instance" => drill.attributes
      )
      score = Score.create!(normalize_payload(result))
      merge_state!("audit_score_id" => score.id)
      { score_id: score.id, points_total: score.points_total }
    end

    def record_edge_audit
      score = Score.find(workflow_run.agent_run_state_json.fetch("audit_score_id"))
      edge = Edge.find(workflow_run.agent_run_state_json.fetch("audit_edge_id"))
      passed = score.points_total.positive?
      EdgeAudit.create!(edge_id: edge.id, drill_instance_id: workflow_run.agent_run_state_json.fetch("audit_drill_instance_id"), passed_bool: passed, schema_version: "1.0.0")
      edge.increment!(:audit_passed_count_int) if passed
      mastery = EdgeMastery.find_or_initialize_by(edge_id: edge.id)
      prior_mastery = mastery.mastery_float.to_f
      observed = passed ? 1.0 : 0.0
      mastery.mastery_float = (0.7 * prior_mastery + 0.3 * observed).round(4)
      mastery.last_seen_at = Time.current
      mastery.schema_version ||= "1.0.0"
      mastery.save!
      if passed
        topic_id = Attempt.find(workflow_run.agent_run_state_json.fetch("audit_attempt_id")).topic_id
        Workflows::RotationPolicy.mark_audit_completed!(user_id: workflow_run.user_id, topic_id: topic_id)
      end
      { passed: passed, edge_id: edge.id }
    end

    def compute_audit_xp
      attempt = Attempt.find(workflow_run.agent_run_state_json.fetch("audit_attempt_id"))
      score = Score.find(workflow_run.agent_run_state_json.fetch("audit_score_id"))
      edge = Edge.find(workflow_run.agent_run_state_json.fetch("audit_edge_id"))
      evt = Workflows::EngineBridge.compute_xp(
        "attempt" => attempt.attributes,
        "score" => score.attributes,
        "ctx" => {
          "base" => 25,
          "points_max" => 25,
          "novelty_factor" => 1.0,
          "spacing_factor" => 1.0,
          "audit_passed_count" => edge.audit_passed_count_int,
          "rewards_edge" => true,
          "edge_xp_today" => 0,
          "topic_xp_today" => 0,
          "edge_id" => edge.id,
          "workflow_run_id" => workflow_run.id
        }
      )
      created = XpEvent.create!(normalize_payload(evt))
      { xp_event_id: created.id, xp: created.xp }
    end

    def recompute_schedule
      schedule = Schedule.find_or_create_by!(user_id: workflow_run.user_id) do |s|
        s.state_json = {}
        s.schema_version = "1.0.0"
      end
      schedule.update!(state_json: schedule.state_json.merge("last_recomputed_at" => Time.current.iso8601))
      { schedule_id: schedule.id }
    end

    def refresh_topic_score
      attempt = Attempt.find(workflow_run.agent_run_state_json.fetch("audit_attempt_id"))
      topic_score = Workflows::TopicScoreUpdater.call(user_id: workflow_run.user_id, topic_id: attempt.topic_id)
      {
        topic_score_id: topic_score.id,
        ous_raw: topic_score.ous_raw_float,
        ous_display: topic_score.ous_display_float
      }
    end

    def check_score_frozen
      session_pack_id = workflow_run.input_json.fetch("session_pack_id")
      pack = SessionPack.find(session_pack_id)
      return { ok: true } if pack.score_frozen?

      raise "Session pack score is not frozen"
    end

    def load_debrief_context
      session_pack = SessionPack.find(workflow_run.input_json.fetch("session_pack_id"))
      attempts = Attempt.where(drill_instance_id: session_pack.drill_instance_ids)
      scores = Score.where(attempt_id: attempts.select(:id))
      merge_state!("debrief_attempt_ids" => attempts.pluck(:id), "debrief_score_ids" => scores.pluck(:id), "topic_id" => session_pack.topic_id)
      { attempts_count: attempts.count, scores_count: scores.count }
    end

    def compile_deterministic_debrief
      scores = Score.where(id: workflow_run.agent_run_state_json.fetch("debrief_score_ids"))
      weak_scores = scores.where("points_total < 10")
      summary = {
        low_score_attempt_ids: weak_scores.pluck(:attempt_id),
        next_actions: weak_scores.any? ? ["Run focused repair on failed edges"] : ["Proceed to interleaving"]
      }
      merge_state!("debrief_summary" => summary)
      summary
    end

    def optional_generate_critique
      return { skipped: true } unless workflow_run.input_json["include_critique"]

      out = Llm::OpenaiClient.new.generate_critique(workflow_run.agent_run_state_json.fetch("debrief_summary"))
      merge_state!("critique_text" => out["critique_text"] || out[:critique_text])
      out
    end

    def persist_debrief
      summary = workflow_run.agent_run_state_json.fetch("debrief_summary")
      created = Debrief.create!(
        workflow_run_id: workflow_run.id,
        user_id: workflow_run.user_id,
        topic_id: workflow_run.agent_run_state_json.fetch("topic_id"),
        summary_json: summary,
        critique_text: workflow_run.agent_run_state_json["critique_text"],
        schema_version: "1.0.0"
      )
      { debrief_id: created.id }
    end

    def load_edge_and_spans
      edge = Edge.find(workflow_run.input_json.fetch("edge_id"))
      topic = edge.graph_version.topic
      source_version = topic.source.source_versions.order(created_at: :desc).first
      candidates = SourceSpan.where(source_version_id: source_version.id).order(:ordinal).limit(20)
      merge_state!("candidate_span_ids" => candidates.pluck(:id), "edge_id" => edge.id)
      { edge_id: edge.id, candidate_span_ids: candidates.pluck(:id) }
    end

    def suggest_evidence_candidates
      out = Llm::OpenaiClient.new.suggest_evidence(
        "edge_id" => workflow_run.agent_run_state_json.fetch("edge_id"),
        "candidate_span_ids" => workflow_run.agent_run_state_json.fetch("candidate_span_ids")
      )
      out
    end

    def load_frozen_snapshot
      session_pack = SessionPack.find(workflow_run.input_json.fetch("session_pack_id"))
      raise "Session not frozen" unless session_pack.score_frozen?

      attempts = Attempt.where(drill_instance_id: session_pack.drill_instance_ids)
      scores = Score.where(attempt_id: attempts.select(:id))
      snapshot = {
        topic_id: session_pack.topic_id,
        graph_version_id: session_pack.graph_version_id,
        scores: scores.map(&:attributes)
      }
      merge_state!("share_snapshot" => snapshot)
      snapshot
    end

    def render_share_pack
      Workflows::RenderSharePack.call(workflow_run.agent_run_state_json.fetch("share_snapshot"))
    end

    def persist_share_pack
      rendered = workflow_run.agent_run_state_json.fetch("last_output", {})
      snapshot = workflow_run.agent_run_state_json.fetch("share_snapshot")
      artifact = SharePackArtifact.create!(
        workflow_run_id: workflow_run.id,
        user_id: workflow_run.user_id,
        topic_id: snapshot.fetch("topic_id"),
        format: rendered["format"] || rendered[:format] || "markdown",
        image_path: rendered["image_path"] || rendered[:image_path],
        markdown_path: rendered["markdown_path"] || rendered[:markdown_path],
        payload_json: rendered,
        schema_version: "1.0.0"
      )
      { share_pack_artifact_id: artifact.id }
    end

    def merge_state!(hash)
      workflow_run.update!(agent_run_state_json: workflow_run.agent_run_state_json.merge(hash))
    end

    def merge_bound_versions!(hash)
      workflow_run.update!(bound_versions_json: workflow_run.bound_versions_json.merge(hash))
    end

    def sha(obj)
      Digest::SHA256.hexdigest(JSON.generate(obj || {}))
    end

    def normalize_payload(payload)
      return payload unless payload.is_a?(Hash)

      payload.each_with_object({}) do |(k, v), h|
        key = k.to_s
        if key.end_with?("_json") || key == "drill_instance_ids" || key == "evidence_refs_json"
          h[key] = v
        else
          h[key] = v
        end
      end
    end

    def json_copy(payload)
      JSON.parse(JSON.generate(payload || {}))
    end

    def self.enqueue(workflow_run_id)
      WorkflowRunJob.perform_later(workflow_run_id)
    end
  end
end
