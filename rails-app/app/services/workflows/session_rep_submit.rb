# frozen_string_literal: true

require "json"

module Workflows
  class SessionRepSubmit
    GEOMETRY_DIAGNOSTICS = %w[rebuild predict break audit].freeze
    FLUENCY_DIAGNOSTICS = %w[rephrase teach].freeze

    BASE_BY_DIAGNOSTIC = {
      "rebuild" => 30,
      "predict" => 20,
      "break" => 20,
      "teach" => 20,
      "rephrase" => 15,
      "audit" => 25
    }.freeze

    TARGET_INTERVAL_DAYS = 2.0
    CANONICAL_SCRIPT_VERSION = "canonical_v1_8m"
    CANONICAL_TOTAL_MS = 8 * 60_000
    CANONICAL_PHASES = [
      { name: "rebuild_from_memory", start_min: 0, end_min: 2, required_diagnostic: "rebuild" },
      { name: "transfer_test", start_min: 2, end_min: 4, required_diagnostic: nil },
      { name: "stress_test", start_min: 4, end_min: 6, required_diagnostic: nil },
      { name: "audit_or_repair", start_min: 6, end_min: 8, required_diagnostic: nil }
    ].freeze

    def self.call(user_id:, session_pack_id:, drill_instance_id:, answer_json:, duration_ms:, source_opened_bool:, workflow_run_id: nil, now: Time.current)
      new(
        user_id: user_id,
        session_pack_id: session_pack_id,
        drill_instance_id: drill_instance_id,
        answer_json: answer_json,
        duration_ms: duration_ms,
        source_opened_bool: source_opened_bool,
        workflow_run_id: workflow_run_id,
        now: now
      ).call
    end

    def initialize(user_id:, session_pack_id:, drill_instance_id:, answer_json:, duration_ms:, source_opened_bool:, workflow_run_id:, now:)
      @user_id = user_id
      @session_pack_id = session_pack_id
      @drill_instance_id = drill_instance_id
      @answer_json = answer_json
      @duration_ms = duration_ms
      @source_opened_bool = source_opened_bool
      @workflow_run_id = workflow_run_id
      @now = now
    end

    def call
      SessionPack.transaction do
        pack = SessionPack.lock.find(session_pack_id)
        validate_pack_access!(pack)
        validate_not_frozen!(pack)
        drill = DrillInstance.lock.find(drill_instance_id)
        validate_drill_membership!(pack, drill)
        validate_version_bindings!(pack, drill)
        progression = Workflows::Progression.snapshot(user_id: user_id, topic_id: pack.topic_id, now: now)
        validate_diagnostic_unlocked!(drill: drill, progression: progression)
        attempts_by_drill = attempts_by_drill(pack)
        validate_canonical_rep_script!(pack: pack, drill: drill, attempts_by_drill: attempts_by_drill)

        attempt, created_attempt = find_or_create_attempt(pack, drill)
        score = find_or_create_score(attempt, drill)
        refresh_edge_mastery_for_attempt!(attempt: attempt, drill: drill, score: score, created_attempt: created_attempt)
        curvature_signal = maybe_record_curvature_signal(attempt: attempt, score: score, created_attempt: created_attempt)
        xp_event = maybe_create_xp_event(attempt: attempt, score: score, drill: drill, created_attempt: created_attempt)
        topic_score = Workflows::TopicScoreUpdater.call(user_id: user_id, topic_id: pack.topic_id, now: now)
        frozen_at = freeze_session_pack_if_complete!(pack)
        final_progression = Workflows::Progression.snapshot(user_id: user_id, topic_id: pack.topic_id, now: now)

        updated_attempts_by_drill = attempts_by_drill.merge(attempt.drill_instance_id.to_s => attempt)
        {
          session_pack_id: pack.id,
          attempt_id: attempt.id,
          score_id: score.id,
          points_total: score.points_total,
          result_code: score.result_code,
          xp_event_id: xp_event&.id,
          xp: xp_event&.xp,
          topic_score_id: topic_score.id,
          ous_display: topic_score.ous_display_float,
          score_frozen_at: frozen_at,
          progression: final_progression,
          curvature_signal_id: curvature_signal&.id,
          curvature_pattern_type: curvature_signal&.pattern_type,
          curvature_stream: recent_curvature_stream(topic_id: pack.topic_id),
          session_timer: current_timer_state(pack: pack, attempts_by_drill: updated_attempts_by_drill)
        }
      end
    end

    private

    attr_reader :user_id, :session_pack_id, :drill_instance_id, :answer_json, :duration_ms, :source_opened_bool, :workflow_run_id, :now

    def validate_pack_access!(pack)
      raise ArgumentError, "Session pack does not belong to user" unless pack.user_id == user_id
    end

    def validate_not_frozen!(pack)
      raise ArgumentError, "Session pack score is frozen" if pack.score_frozen?
    end

    def validate_drill_membership!(pack, drill)
      drill_ids = Array(pack.drill_instance_ids).map(&:to_s)
      raise ArgumentError, "Drill instance is not part of session pack" unless drill_ids.include?(drill.id.to_s)
    end

    def validate_version_bindings!(pack, drill)
      raise ArgumentError, "Graph version binding mismatch" unless drill.graph_version_id == pack.graph_version_id
      raise ArgumentError, "Source version binding mismatch" unless drill.source_version_id == pack.source_version_id
      raise ArgumentError, "Rubric version binding mismatch" unless drill.rubric_version_id == pack.rubric_version_id
    end

    def validate_diagnostic_unlocked!(drill:, progression:)
      unlocked = Array(progression[:unlocked_diagnostics]).map(&:to_s)
      return if unlocked.include?(drill.diagnostic.to_s)

      raise ArgumentError, "Diagnostic #{drill.diagnostic} is locked for tier #{progression[:tier_name]}"
    end

    def find_or_create_attempt(pack, drill)
      existing = Attempt.find_by(user_id: user_id, drill_instance_id: drill.id)
      if existing
        same_payload = existing.answer_json == normalized_answer && existing.source_opened_bool == !!source_opened_bool
        raise ArgumentError, "Attempt already exists for drill with a different payload" unless same_payload

        return [existing, false]
      end

      attempt = Attempt.create!(
        user_id: user_id,
        topic_id: pack.topic_id,
        graph_version_id: pack.graph_version_id,
        source_version_id: pack.source_version_id,
        drill_instance_id: drill.id,
        rubric_version_id: pack.rubric_version_id,
        diagnostic: drill.diagnostic,
        answer_json: normalized_answer,
        duration_ms: normalized_duration_ms,
        source_opened_bool: !!source_opened_bool,
        schema_version: "1.0.0"
      )
      Schemas::Validator.call!(schema_name: "attempt", payload: attempt.attributes)
      [attempt, true]
    end

    def find_or_create_score(attempt, drill)
      existing = Score.find_by(attempt_id: attempt.id)
      return existing if existing

      computed = Workflows::EngineBridge.compute_score(
        "attempt" => attempt.attributes,
        "drill_instance" => drill.attributes
      )
      score = Score.create!(computed)
      Schemas::Validator.call!(schema_name: "score", payload: score.attributes)
      score
    end

    def maybe_create_xp_event(attempt:, score:, drill:, created_attempt:)
      return nil unless created_attempt
      return nil unless score.result_code == "scored"

      edge_id = rewarded_edge_id_for(drill)
      edge = edge_id && Edge.find_by(id: edge_id)
      context = xp_context(attempt: attempt, drill: drill, score: score, edge: edge)
      xp_payload = Workflows::EngineBridge.compute_xp(
        "attempt" => attempt.attributes,
        "score" => score.attributes,
        "ctx" => context
      )
      XpEvent.create!(xp_payload)
    end

    def xp_context(attempt:, drill:, score:, edge:)
      {
        "base" => BASE_BY_DIAGNOSTIC.fetch(drill.diagnostic, 15),
        "points_max" => points_max_for(drill.diagnostic),
        "novelty_factor" => novelty_factor(attempt: attempt),
        "spacing_factor" => spacing_factor(attempt: attempt),
        "audit_passed_count" => edge&.audit_passed_count_int || 0,
        "rewards_edge" => !edge.nil?,
        "edge_xp_today" => xp_today_for(edge_id: edge&.id),
        "topic_xp_today" => xp_today_for(topic_id: attempt.topic_id),
        "edge_id" => edge&.id,
        "workflow_run_id" => resolved_workflow_run_id
      }
    end

    def points_max_for(diagnostic)
      case diagnostic
      when "rebuild" then 30
      when "audit" then 25
      else 20
      end
    end

    def novelty_factor(attempt:)
      if FLUENCY_DIAGNOSTICS.include?(attempt.diagnostic) && !geometry_activity_recent?(attempt: attempt)
        return 0.2
      end

      recent_scored = Attempt
        .joins(:score)
        .where(user_id: user_id, topic_id: attempt.topic_id)
        .where.not(id: attempt.id)
        .where("scores.result_code = ?", "scored")
        .where("attempts.created_at >= ?", (now - 7.days))

      return 1.0 if recent_scored.none?
      return 0.1 if recent_scored.where(drill_instance_id: attempt.drill_instance_id).exists?

      0.5
    end

    def geometry_activity_recent?(attempt:)
      Attempt
        .joins(:score)
        .where(user_id: user_id, topic_id: attempt.topic_id)
        .where.not(id: attempt.id)
        .where(diagnostic: GEOMETRY_DIAGNOSTICS)
        .where("scores.result_code = ?", "scored")
        .where("attempts.created_at >= ?", (now - 24.hours))
        .exists?
    end

    def spacing_factor(attempt:)
      previous = Attempt
        .where(user_id: user_id, topic_id: attempt.topic_id)
        .where.not(id: attempt.id)
        .order(created_at: :desc)
        .first
      return 1.0 unless previous

      days = ((now.to_f - previous.created_at.to_f) / 86_400.0)
      raw = days / TARGET_INTERVAL_DAYS
      [[raw, 0.25].max, 1.0].min
    end

    def rewarded_edge_id_for(drill)
      return nil unless drill.diagnostic == "audit"

      payload = drill.prompt_payload_json || {}
      payload["edge_id"] || payload[:edge_id]
    end

    def xp_today_for(topic_id: nil, edge_id: nil)
      scope = XpEvent.where(user_id: user_id, created_at: now.all_day)
      scope = scope.where(topic_id: topic_id) if topic_id
      scope = scope.where(edge_id: edge_id) if edge_id
      scope.sum(:xp)
    end

    def freeze_session_pack_if_complete!(pack)
      drill_ids = Array(pack.drill_instance_ids)
      return pack.score_frozen_at if drill_ids.empty?

      scored_drill_count = Score
        .joins(:attempt)
        .where(attempts: { user_id: user_id, drill_instance_id: drill_ids })
        .distinct
        .count("attempts.drill_instance_id")

      return pack.score_frozen_at if scored_drill_count < drill_ids.size

      pack.update!(score_frozen_at: now) unless pack.score_frozen?
      pack.score_frozen_at
    end

    def maybe_record_curvature_signal(attempt:, score:, created_attempt:)
      return nil unless created_attempt

      Workflows::CurvatureDiagnostics.call(
        user_id: user_id,
        topic_id: attempt.topic_id,
        attempt: attempt,
        score: score,
        now: now
      )
    end

    def recent_curvature_stream(topic_id:)
      CurvatureSignal
        .where(topic_id: topic_id)
        .order(created_at: :desc)
        .limit(5)
        .map do |signal|
          {
            id: signal.id,
            pattern_type: signal.pattern_type,
            created_at: signal.created_at&.utc&.iso8601,
            evidence_json: signal.evidence_json
          }
        end
    end

    def validate_canonical_rep_script!(pack:, drill:, attempts_by_drill:)
      ordered_ids = ordered_drill_ids(pack)
      ordered_drills = DrillInstance.where(id: ordered_ids).index_by { |item| item.id.to_s }
      if ordered_drills.length != ordered_ids.length
        raise ArgumentError, "Session pack references missing drill instances"
      end

      if ordered_ids.length > CANONICAL_PHASES.length
        raise ArgumentError, "Session pack has #{ordered_ids.length} drills; canonical 8-minute script supports up to #{CANONICAL_PHASES.length}"
      end

      first = ordered_drills[ordered_ids.first]
      if first&.diagnostic != "rebuild"
        raise ArgumentError, "Canonical script requires first drill diagnostic to be rebuild"
      end

      index = ordered_ids.index(drill.id.to_s)
      raise ArgumentError, "Drill instance is not part of canonical script order" if index.nil?

      phase = CANONICAL_PHASES[index]
      required = phase[:required_diagnostic]
      if required && drill.diagnostic != required
        raise ArgumentError, "Phase #{phase[:name]} requires diagnostic=#{required}"
      end

      existing_attempt = attempts_by_drill[drill.id.to_s]
      unless existing_attempt
        next_index = ordered_ids.index { |id| !attempts_by_drill.key?(id) }
        raise ArgumentError, "Session script is already complete" if next_index.nil?
        if index != next_index
          expected_drill_id = ordered_ids[next_index]
          raise ArgumentError, "Session script order violation: expected drill #{expected_drill_id} next"
        end

        if normalized_duration_ms > phase_budget_ms(phase)
          raise ArgumentError, "Duration exceeds phase budget for #{phase[:name]} (max #{phase_budget_ms(phase)}ms)"
        end

        elapsed_before = ordered_ids.take(index).sum { |id| attempts_by_drill[id]&.duration_ms.to_i }
        elapsed_after = elapsed_before + normalized_duration_ms
        phase_end_ms = phase_end_ms(phase)
        if elapsed_after > phase_end_ms
          raise ArgumentError, "Duration exceeds script phase boundary for #{phase[:name]} (end #{phase_end_ms}ms)"
        end
        if elapsed_after > CANONICAL_TOTAL_MS
          raise ArgumentError, "Duration exceeds canonical 8-minute total (#{CANONICAL_TOTAL_MS}ms)"
        end
      end
    end

    def attempts_by_drill(pack)
      Attempt
        .where(user_id: user_id, drill_instance_id: ordered_drill_ids(pack))
        .index_by { |attempt| attempt.drill_instance_id.to_s }
    end

    def current_timer_state(pack:, attempts_by_drill:)
      drill_ids = ordered_drill_ids(pack)
      elapsed_ms = drill_ids.sum { |id| attempts_by_drill[id]&.duration_ms.to_i }
      remaining_ms = [CANONICAL_TOTAL_MS - elapsed_ms, 0].max
      next_index = drill_ids.index { |id| !attempts_by_drill.key?(id) }
      next_phase = next_index && CANONICAL_PHASES[next_index]

      {
        script_version: CANONICAL_SCRIPT_VERSION,
        total_budget_ms: CANONICAL_TOTAL_MS,
        elapsed_ms: elapsed_ms,
        remaining_ms: remaining_ms,
        completed_drills: drill_ids.count { |id| attempts_by_drill.key?(id) },
        total_drills: drill_ids.length,
        next_drill_instance_id: next_index ? drill_ids[next_index] : nil,
        next_phase: next_phase && {
          name: next_phase[:name],
          start_ms: phase_start_ms(next_phase),
          end_ms: phase_end_ms(next_phase)
        }
      }
    end

    def refresh_edge_mastery_for_attempt!(attempt:, drill:, score:, created_attempt:)
      return unless created_attempt
      return unless score.result_code == "scored"

      edge_ids = touched_edge_ids_for(attempt: attempt, drill: drill)
      return if edge_ids.empty?

      correctness = clamp(score.points_total.to_f / [points_max_for(drill.diagnostic), 1].max, 0.0, 1.0)
      edge_ids.each do |edge_id|
        mastery = EdgeMastery.find_or_initialize_by(edge_id: edge_id)
        prior = mastery.mastery_float.to_f
        mastery.mastery_float = (0.7 * prior + 0.3 * correctness).round(4)
        mastery.last_seen_at = now
        mastery.schema_version ||= "1.0.0"
        mastery.save!
      end
    end

    def touched_edge_ids_for(attempt:, drill:)
      payload = attempt.answer_json.is_a?(Hash) ? attempt.answer_json : {}
      key = drill.answer_key_json.is_a?(Hash) ? drill.answer_key_json : {}

      external_edge_ids = []
      external_edge_ids.concat(Array(payload["edge_ids"] || payload[:edge_ids]))
      external_edge_ids.concat(Array(payload["path_edge_ids_in_order"] || payload[:path_edge_ids_in_order]))
      external_edge_ids.concat(Array(payload["missing_edge_ids"] || payload[:missing_edge_ids]))
      external_edge_ids << (payload["broken_edge_id"] || payload[:broken_edge_id])
      external_edge_ids.concat(Array(key["expected_edge_ids"] || key[:expected_edge_ids]))
      external_edge_ids.concat(Array(key["expected_missing_edge_ids"] || key[:expected_missing_edge_ids]))
      external_edge_ids.concat(Array(key["valid_paths"] || key[:valid_paths]).flatten)
      external_edge_ids << (key["broken_edge_id"] || key[:broken_edge_id])
      external_edge_ids << rewarded_edge_id_for(drill)
      external_edge_ids = external_edge_ids.compact.map(&:to_s).uniq
      return [] if external_edge_ids.empty?

      Edge
        .where(graph_version_id: drill.graph_version_id)
        .where("id IN (:ids) OR edge_id IN (:ids)", ids: external_edge_ids)
        .pluck(:id)
    end

    def ordered_drill_ids(pack)
      Array(pack.drill_instance_ids).map(&:to_s)
    end

    def phase_start_ms(phase)
      phase.fetch(:start_min) * 60_000
    end

    def phase_end_ms(phase)
      phase.fetch(:end_min) * 60_000
    end

    def phase_budget_ms(phase)
      phase_end_ms(phase) - phase_start_ms(phase)
    end

    def normalized_duration_ms
      @normalized_duration_ms ||= Integer(duration_ms || 0)
    end

    def resolved_workflow_run_id
      workflow_run_id.presence || "session_pack:#{session_pack_id}"
    end

    def clamp(value, min, max)
      [[value, min].max, max].min
    end

    def normalized_answer
      return {} unless answer_json.is_a?(Hash)

      JSON.parse(JSON.generate(answer_json))
    end
  end
end
