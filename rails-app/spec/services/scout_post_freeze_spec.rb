# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::ScoutPostFreeze do
  it "enforces freeze gate and persists normalized scout artifact" do
    source = Source.create!(url: "https://example.com/scout")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "sv_scout",
      extracted_text: "Paragraph",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Scout Topic", source_id: source.id, schema_version: "1.0.0")
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "rv_scout", schema_version: "1.0.0")
    n1 = Node.create!(graph_version_id: graph.id, node_id: "n1", label: "N1", definition_1s: "D1", schema_version: "1.0.0")
    n2 = Node.create!(graph_version_id: graph.id, node_id: "n2", label: "N2", definition_1s: "D2", schema_version: "1.0.0")
    e1 = Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e1",
      from_node_id: n1.node_id,
      to_node_id: n2.node_id,
      edge_type: "causal",
      mechanism_json: { mediator: "n1", observable: "n2", failure_mode: "x", intervention: "y" },
      is_anchor: true,
      schema_version: "1.0.0"
    )
    e2 = Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e2",
      from_node_id: n2.node_id,
      to_node_id: n1.node_id,
      edge_type: "dependency",
      mechanism_json: { mediator: "n2", observable: "n1", failure_mode: "x", intervention: "y" },
      is_anchor: true,
      schema_version: "1.0.0"
    )
    drill = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      seed: 77,
      prompt_payload_json: {},
      answer_key_json: { correct_prediction_choice_id: "pred_e1" },
      schema_version: "1.0.0"
    )
    pack = SessionPack.create!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      drill_instance_ids: [drill.id],
      score_frozen_at: Time.current,
      schema_version: "1.0.0"
    )
    attempt = Attempt.create!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      drill_instance_id: drill.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      answer_json: { prediction_choice_id: "pred_e1", confidence_0_1: 0.9 },
      duration_ms: 1000,
      source_opened_bool: false,
      schema_version: "1.0.0"
    )
    Score.create!(
      attempt_id: attempt.id,
      points_total: 14,
      points_by_dimension_json: {},
      evidence_refs_json: [],
      result_code: "scored",
      schema_version: "1.0.0"
    )

    allow_any_instance_of(Llm::OpenaiClient).to receive(:generate_scout).and_return(
      scout_output: {
        counterexamples: [
          { edge_id: e1.edge_id, text: "Counterexample one" },
          { edge_id: e2.edge_id, text: "Counterexample two" }
        ],
        alternate_framing: { node_ids: [n1.node_id], text: "Alternative framing." },
        failure_mode: "Failure mode."
      },
      provider: "test",
      model: "fake",
      policy_decision: "allow",
      redactions_applied_json: []
    )

    result = described_class.call(user_id: "user_v1", session_pack_id: pack.id)
    expect(result[:scout_artifact_id]).to be_present
    expect(result[:scout_output]["counterexamples"].size).to eq(2)
    expect(result[:scout_output]["counterexamples"].first["edge_id"]).to eq(e1.edge_id)
  end
end
