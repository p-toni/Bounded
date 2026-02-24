# frozen_string_literal: true

require "digest"
require "json"

module Workflows
  class ExportBundle
    def self.call(user_id:, scope:)
      new(user_id: user_id, scope: scope).call
    end

    def initialize(user_id:, scope:)
      @user_id = user_id
      @scope = scope.to_s
    end

    def call
      topic_ids = resolved_topic_ids
      source_ids = Topic.where(id: topic_ids).pluck(:source_id).compact.uniq
      graph_ids = GraphVersion.where(topic_id: topic_ids).pluck(:id)
      edge_ids = Edge.where(graph_version_id: graph_ids).pluck(:id)
      drill_ids = DrillInstance.where(topic_id: topic_ids).pluck(:id)
      attempt_ids = Attempt.where(user_id: user_id, topic_id: topic_ids).pluck(:id)

      bundle = {
        schema_version: "1.0.0",
        exported_at: Time.current.iso8601,
        scope: scope,
        user_id: user_id,
        sources: Source.where(id: source_ids).map(&:as_json),
        source_versions: SourceVersion.where(source_id: source_ids).map(&:as_json),
        source_spans: SourceSpan.where(source_version_id: SourceVersion.where(source_id: source_ids).select(:id)).map(&:as_json),
        topics: Topic.where(id: topic_ids).map(&:as_json),
        graph_versions: GraphVersion.where(id: graph_ids).map(&:as_json),
        nodes: Node.where(graph_version_id: graph_ids).map(&:as_json),
        edges: Edge.where(id: edge_ids).map(&:as_json),
        edge_evidence: EdgeEvidence.where(edge_id: edge_ids).map(&:as_json),
        drill_instances: DrillInstance.where(id: drill_ids).map(&:as_json),
        attempts: Attempt.where(id: attempt_ids).map(&:as_json),
        scores: Score.where(attempt_id: attempt_ids).map(&:as_json),
        edge_audits: EdgeAudit.where(edge_id: edge_ids).map(&:as_json),
        edge_mastery: EdgeMastery.where(edge_id: edge_ids).map(&:as_json),
        topic_scores: TopicScore.where(topic_id: topic_ids).map(&:as_json),
        schedules: Schedule.where(user_id: user_id).map(&:as_json),
        xp_events: XpEvent.where(user_id: user_id, topic_id: topic_ids).map(&:as_json),
        curvature_signals: CurvatureSignal.where(topic_id: topic_ids).map(&:as_json)
      }

      {
        bundle: bundle,
        payload_hash: Digest::SHA256.hexdigest(JSON.generate(bundle))
      }
    end

    private

    attr_reader :user_id, :scope

    def resolved_topic_ids
      if scope == "workspace:all"
        Topic.where(user_id: user_id).pluck(:id)
      elsif scope.start_with?("topic:")
        topic_id = scope.split(":", 2).last
        topic = Topic.find_by!(id: topic_id, user_id: user_id)
        [topic.id]
      else
        raise ArgumentError, "unsupported export scope: #{scope}"
      end
    end
  end
end
