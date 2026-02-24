# frozen_string_literal: true

module Workflows
  class DeleteScope
    def self.call(user_id:, scope:)
      new(user_id: user_id, scope: scope).call
    end

    def initialize(user_id:, scope:)
      @user_id = user_id
      @scope = scope.to_s
    end

    def call
      Topic.transaction do
        topic_ids = resolved_topic_ids
        counts = delete_topic_scope(topic_ids: topic_ids)
        { scope: scope, deleted: counts }
      end
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
        raise ArgumentError, "unsupported delete scope: #{scope}"
      end
    end

    def delete_topic_scope(topic_ids:)
      source_ids = Topic.where(id: topic_ids).pluck(:source_id).compact.uniq
      graph_ids = GraphVersion.where(topic_id: topic_ids).pluck(:id)
      edge_ids = Edge.where(graph_version_id: graph_ids).pluck(:id)
      drill_ids = DrillInstance.where(topic_id: topic_ids).pluck(:id)
      attempt_ids = Attempt.where(user_id: user_id, topic_id: topic_ids).pluck(:id)
      workflow_run_ids = WorkflowRun.where(user_id: user_id).pluck(:id)
      session_pack_ids = SessionPack.where(topic_id: topic_ids, user_id: user_id).pluck(:id)

      counts = {}
      counts[:scores] = Score.where(attempt_id: attempt_ids).delete_all
      counts[:attempts] = Attempt.where(id: attempt_ids).delete_all
      counts[:edge_audits] = EdgeAudit.where(edge_id: edge_ids).delete_all
      counts[:xp_events] = XpEvent.where(user_id: user_id, topic_id: topic_ids).delete_all
      counts[:edge_mastery] = EdgeMastery.where(edge_id: edge_ids).delete_all
      counts[:edge_evidence] = EdgeEvidence.where(edge_id: edge_ids).delete_all
      counts[:edges] = Edge.where(id: edge_ids).delete_all
      counts[:nodes] = Node.where(graph_version_id: graph_ids).delete_all
      counts[:graph_versions] = GraphVersion.where(id: graph_ids).delete_all
      counts[:drill_instances] = DrillInstance.where(id: drill_ids).delete_all
      counts[:topic_scores] = TopicScore.where(topic_id: topic_ids).delete_all
      counts[:curvature_signals] = CurvatureSignal.where(topic_id: topic_ids).delete_all
      counts[:scout_artifacts] = ScoutArtifact.where(session_pack_id: session_pack_ids, user_id: user_id).delete_all
      counts[:session_packs] = SessionPack.where(id: session_pack_ids).delete_all
      counts[:debriefs] = Debrief.where(topic_id: topic_ids, user_id: user_id).delete_all
      counts[:share_pack_artifacts] = SharePackArtifact.where(topic_id: topic_ids, user_id: user_id).delete_all
      counts[:topics] = Topic.where(id: topic_ids).delete_all

      remaining_source_ids = Topic.where(source_id: source_ids).pluck(:source_id).uniq
      deletable_source_ids = source_ids - remaining_source_ids
      source_version_ids = SourceVersion.where(source_id: deletable_source_ids).pluck(:id)
      counts[:source_spans] = SourceSpan.where(source_version_id: source_version_ids).delete_all
      counts[:source_versions] = SourceVersion.where(id: source_version_ids).delete_all
      counts[:sources] = Source.where(id: deletable_source_ids).delete_all

      if scope == "workspace:all"
        counts[:workflow_step_events] = WorkflowStepEvent.where(workflow_run_id: workflow_run_ids).delete_all
        counts[:tool_call_logs] = ToolCallLog.where(workflow_run_id: workflow_run_ids).delete_all
        counts[:scout_artifacts] = (counts[:scout_artifacts] || 0) + ScoutArtifact.where(user_id: user_id).delete_all
        counts[:workflow_runs] = WorkflowRun.where(id: workflow_run_ids).delete_all
        counts[:schedules] = Schedule.where(user_id: user_id).delete_all
        counts[:approval_tokens] = ApprovalToken.where(user_id: user_id).delete_all
      end

      counts
    end
  end
end
