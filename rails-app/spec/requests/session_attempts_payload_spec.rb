# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session attempts payload", type: :request do
  it "passes structured answer_json through to session submit workflow" do
    payload = {
      "node_ids" => %w[n1 n2],
      "edge_ids" => %w[e1 e2],
      "edge_types_by_edge_id" => { "e1" => "causal", "e2" => "constraint" }
    }

    captured = nil
    allow(Workflows::SessionRepSubmit).to receive(:call) do |args|
      captured = args
      {
        session_pack_id: "pack_1",
        attempt_id: "attempt_1",
        score_id: "score_1",
        points_total: 25,
        result_code: "scored"
      }
    end

    post "/session_packs/pack_1/attempts",
         params: {
           attempt: {
             drill_instance_id: "dr_1",
             duration_ms: 60_000,
             source_opened_bool: false,
             answer_json: payload
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(captured).to include(
      user_id: "user_v1",
      session_pack_id: "pack_1",
      drill_instance_id: "dr_1",
      duration_ms: 60_000,
      source_opened_bool: false,
      workflow_run_id: nil
    )
    expect(captured[:answer_json]).to eq(payload)
  end
end
