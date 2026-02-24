# frozen_string_literal: true

module Tools
  class Envelope
    MAP = {
      "prepare_rep" => %w[schedule.get topic.get graph_version.get edge_evidence.list source_span.list drill_instance.create session_pack.create],
      "run_reality_audit" => %w[drill_instance.create attempt.create score.compute edge_audit.record xp.compute schedule.recompute],
      "post_session_debrief" => %w[score.get attempt.get graph_version.get topic_score.get curvature_signal.list debrief.create critique_text.generate scout.invoke],
      "evidence_assist" => %w[source_span.list edge.get edge_evidence.suggest_candidates],
      "render_share_pack" => %w[graph_version.get scores.get edge_evidence.list share_pack.render]
    }.freeze

    OUT_OF_WORKFLOW_ALLOWLIST = %w[
      source.ingest
      source.get
      source_version.get
      source_span.get
      topic_score.get
      approval_token.issue
      export.bundle
      delete.scope
      scout.invoke
    ].freeze

    def self.allowed?(workflow_type:, tool_name:)
      return OUT_OF_WORKFLOW_ALLOWLIST.include?(tool_name) if workflow_type.nil?

      Array(MAP[workflow_type]).include?(tool_name)
    end

    def self.assert_allowed!(workflow_type:, tool_name:)
      return if allowed?(workflow_type: workflow_type, tool_name: tool_name)

      raise Tools::Registry::PermissionDenied, "Tool #{tool_name} is not allowed for workflow #{workflow_type}"
    end
  end
end
