# frozen_string_literal: true

require "digest"
require "json"

begin
  require "geometry_gym_engine"
rescue LoadError
  engine_path = Rails.root.join("..", "engine-ruby", "lib").to_s
  $LOAD_PATH.unshift(engine_path) unless $LOAD_PATH.include?(engine_path)
  require "geometry_gym_engine"
end

module Workflows
  class EngineBridge
    def self.compute_score(input)
      attempt = input.fetch("attempt")
      drill = input.fetch("drill_instance")
      GeometryGymEngine::Score::Compute.call(
        attempt: symbolize(attempt),
        drill_instance: symbolize(drill)
      )
    end

    def self.compute_xp(input)
      GeometryGymEngine::XP::Compute.call(
        attempt: symbolize(input.fetch("attempt")),
        score: symbolize(input.fetch("score")),
        ctx: symbolize(input.fetch("ctx"))
      )
    end

    def self.compute_ous(topic_ctx:)
      GeometryGymEngine::OUS::Compute.call(
        topic_ctx: symbolize(topic_ctx)
      )
    end

    def self.fetch_url(url:)
      GeometryGymEngine::Ingest::Fetch.call(url)
    end

    def self.extract_content(raw_html:)
      GeometryGymEngine::Parse::Extract.call(raw_html)
    end

    def self.paragraph_spans(source_version_id:, extracted_text:)
      GeometryGymEngine::Segment::ParagraphSpans.call(
        source_version_id: source_version_id,
        extracted_text: extracted_text
      )
    end

    def self.generate_session_pack(topic_ctx:, rotation:, rubric_version_id:)
      GeometryGymEngine::Drills::GenerateSessionPack.call(
        topic_ctx: symbolize(topic_ctx),
        rotation: rotation,
        rubric_version_id: rubric_version_id
      )
    end

    def self.generate_audit_instance(topic_ctx:, target_edge_id:)
      GeometryGymEngine::Drills::GenerateAuditInstance.call(
        topic_ctx: symbolize(topic_ctx),
        target_edge_id: target_edge_id
      )
    end

    def self.build_schedule_queue(topics:, schedule_state:, now:, audit_interval_days:, curvature_window_days:)
      GeometryGymEngine::Schedule::BuildQueue.call(
        topics: symbolize(topics),
        schedule_state: symbolize(schedule_state || {}),
        now: now,
        audit_interval_days: audit_interval_days,
        curvature_window_days: curvature_window_days
      )
    end

    def self.validate_anchor_evidence(graph_edges:, edge_evidences:)
      GeometryGymEngine::Graph::ValidateAnchorEvidence.call(
        graph_edges: graph_edges.map { |x| symbolize(x) },
        edge_evidences: edge_evidences.map { |x| symbolize(x) }
      )
    end

    def self.replay(workflow_run:, step_events:)
      GeometryGymEngine::Replay::ReplayWorkflow.call(
        workflow_run: symbolize(workflow_run),
        step_events: step_events.map { |x| symbolize(x) }
      )
    end

    def self.symbolize(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize(v) }
      when Array
        obj.map { |v| symbolize(v) }
      else
        obj
      end
    end
  end
end
