# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkflowRun inspector filters", type: :request do
  it "filters by step and tool criteria" do
    run = WorkflowRun.create!(
      user_id: "user_v1",
      workflow_type: "prepare_rep",
      status: "running",
      idempotency_key: "idem-inspector-1",
      input_json: {},
      bound_versions_json: { "schema_version" => "1.0.0", "policy_version" => "v1" },
      agent_run_state_json: { "step_index" => 2 },
      schema_version: "1.0.0"
    )

    started = WorkflowStepEvent.create!(
      workflow_run_id: run.id,
      step_name: "resolve_topic",
      step_status: "started",
      input_json: {},
      output_json: {},
      bound_versions_json: {},
      input_hash: "in1",
      output_hash: "out1",
      tool_schema_version: "1.0.0",
      schema_version: "1.0.0"
    )
    completed = WorkflowStepEvent.create!(
      workflow_run_id: run.id,
      step_name: "generate_drill_instances",
      step_status: "completed",
      input_json: {},
      output_json: { "ok" => true },
      bound_versions_json: {},
      input_hash: "in2",
      output_hash: "out2",
      tool_schema_version: "1.0.0",
      schema_version: "1.0.0"
    )

    ToolCallLog.create!(
      workflow_run_id: run.id,
      step_event_id: started.id,
      tool_name: "topic.get",
      input_json: {},
      output_json: {},
      policy_json: {},
      schema_version: "1.0.0"
    )
    ToolCallLog.create!(
      workflow_run_id: run.id,
      step_event_id: completed.id,
      tool_name: "drill_instance.create",
      input_json: {},
      output_json: {},
      policy_json: {},
      schema_version: "1.0.0"
    )

    get "/workflow_runs/#{run.id}/inspector", params: {
      step_name: "generate_drill_instances",
      step_status: "completed",
      tool_name: "drill_instance.create"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("generate_drill_instances")
    expect(response.body).to include("drill_instance.create")
    expect(response.body).not_to include("resolve_topic")
    expect(response.body).not_to include("topic.get")
  end
end
