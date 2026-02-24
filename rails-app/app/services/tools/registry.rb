# frozen_string_literal: true

module Tools
  class Registry
    class UnknownTool < StandardError; end
    class PermissionDenied < StandardError; end

    TOOL_MAP = {
      "source.ingest" => lambda { |input, ctx|
        Workflows::SourceIngest.call(
          user_id: ctx[:user_id] || ctx["user_id"],
          url: input.fetch("url"),
          topic_title: input["topic_title"]
        )
      },
      "source.get" => ->(input, _ctx) { Source.find(input.fetch("id")).as_json },
      "source_version.get" => ->(input, _ctx) { SourceVersion.find(input.fetch("id")).as_json },
      "schedule.get" => ->(input, _ctx) { Schedule.find_by(user_id: input.fetch("user_id"))&.as_json || {} },
      "topic.get" => ->(input, _ctx) { Topic.find(input.fetch("id")).as_json },
      "graph_version.get" => ->(input, _ctx) { GraphVersion.find(input.fetch("id")).as_json },
      "edge_evidence.list" => ->(input, _ctx) { EdgeEvidence.where(edge_id: input.fetch("edge_id")).map(&:as_json) },
      "source_span.list" => ->(input, _ctx) { SourceSpan.where(source_version_id: input.fetch("source_version_id")).order(:ordinal).map(&:as_json) },
      "source_span.get" => ->(input, _ctx) { SourceSpan.find(input.fetch("id")).as_json },
      "edge.get" => ->(input, _ctx) { Edge.find(input.fetch("id")).as_json },
      "drill_instance.create" => ->(input, _ctx) { DrillInstance.create!(input).as_json },
      "session_pack.create" => ->(input, _ctx) { SessionPack.create!(input).as_json },
      "attempt.create" => ->(input, _ctx) { Attempt.create!(input).as_json },
      "score.compute" => ->(input, _ctx) { Workflows::EngineBridge.compute_score(input).as_json },
      "score.get" => ->(input, _ctx) { Score.find(input.fetch("id")).as_json },
      "attempt.get" => ->(input, _ctx) { Attempt.find(input.fetch("id")).as_json },
      "scores.get" => ->(input, _ctx) { Score.where(attempt_id: input.fetch("attempt_ids")).map(&:as_json) },
      "topic_score.get" => lambda { |input, ctx|
        score = TopicScore.find_by(topic_id: input.fetch("topic_id"))
        score ||= Workflows::TopicScoreUpdater.call(
          user_id: (ctx[:user_id] || ctx["user_id"]),
          topic_id: input.fetch("topic_id")
        )
        score.as_json
      },
      "approval_token.issue" => lambda { |input, ctx|
        Security::ApprovalTokens.issue(
          user_id: ctx[:user_id] || ctx["user_id"],
          action: input.fetch("action"),
          scope: input.fetch("scope"),
          resource_id: input["resource_id"],
          ttl_minutes: input["ttl_minutes"]
        )
      },
      "export.bundle" => lambda { |input, ctx|
        Security::ApprovalTokens.consume!(
          user_id: ctx[:user_id] || ctx["user_id"],
          action: "export",
          scope: input.fetch("scope"),
          approval_token: input.fetch("approval_token")
        )
        Workflows::ExportBundle.call(
          user_id: ctx[:user_id] || ctx["user_id"],
          scope: input.fetch("scope")
        )
      },
      "delete.scope" => lambda { |input, ctx|
        Security::ApprovalTokens.consume!(
          user_id: ctx[:user_id] || ctx["user_id"],
          action: "delete",
          scope: input.fetch("scope"),
          approval_token: input.fetch("approval_token")
        )
        Workflows::DeleteScope.call(
          user_id: ctx[:user_id] || ctx["user_id"],
          scope: input.fetch("scope")
        )
      },
      "scout.invoke" => lambda { |input, ctx|
        Workflows::ScoutPostFreeze.call(
          user_id: ctx[:user_id] || ctx["user_id"],
          session_pack_id: input.fetch("session_pack_id"),
          workflow_run_id: ctx[:workflow_run_id] || ctx["workflow_run_id"]
        )
      },
      "curvature_signal.list" => ->(input, _ctx) { CurvatureSignal.where(topic_id: input.fetch("topic_id")).map(&:as_json) },
      "debrief.create" => ->(input, _ctx) { Debrief.create!(input).as_json },
      "edge_audit.record" => ->(input, _ctx) { EdgeAudit.create!(input).as_json },
      "xp.compute" => ->(input, _ctx) { Workflows::EngineBridge.compute_xp(input).as_json },
      "schedule.recompute" => lambda { |input, _ctx|
        schedule = Schedule.find_or_create_by!(user_id: input.fetch("user_id")) { |s| s.state_json = {}; s.schema_version = "1.0.0" }
        schedule.update!(state_json: schedule.state_json.merge("last_recomputed_at" => Time.current.iso8601))
        schedule.as_json
      },
      "share_pack.render" => ->(input, _ctx) { Workflows::RenderSharePack.call(input) },
      "critique_text.generate" => ->(input, _ctx) { Llm::OpenaiClient.new.generate_critique(input) },
      "edge_evidence.suggest_candidates" => ->(input, _ctx) { Llm::OpenaiClient.new.suggest_evidence(input) }
    }.freeze

    def self.call(name:, input_json:, context:)
      fn = TOOL_MAP[name]
      raise UnknownTool, "Tool not found: #{name}" unless fn

      workflow_type = context[:workflow_type] || context["workflow_type"]
      Tools::Envelope.assert_allowed!(workflow_type: workflow_type, tool_name: name)

      output = fn.call(input_json, context)
      ToolCallLog.create!(
        workflow_run_id: context[:workflow_run_id] || context["workflow_run_id"],
        step_event_id: context[:step_event_id] || context["step_event_id"],
        tool_name: name,
        input_json: input_json,
        output_json: output,
        policy_json: {
          workflow_type: workflow_type,
          policy_decision: "allow"
        },
        schema_version: "1.0.0"
      )
      output
    end
  end
end
