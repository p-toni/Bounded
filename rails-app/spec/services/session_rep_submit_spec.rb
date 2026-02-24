# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::SessionRepSubmit do
  def setup_topic_stack
    source = Source.create!(url: "https://example.com/article")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "hash-v1",
      extracted_text: "Paragraph one.\n\nParagraph two.",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Topic", source_id: source.id)
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "v1", schema_version: "1.0.0")
    [topic, graph, source_version, rubric]
  end

  def build_session_pack!(topic:, graph:, source_version:, rubric:, drills:)
    SessionPack.create!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      drill_instance_ids: drills.map(&:id),
      schema_version: "1.0.0"
    )
  end

  it "creates attempts and freezes session when all drills are scored" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 11,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1 n2 n3],
        expected_edge_ids: %w[e1 e2],
        expected_edge_types_by_edge_id: { "e1" => "causal", "e2" => "dependency" }
      },
      schema_version: "1.0.0"
    )
    predict = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      seed: 12,
      prompt_payload_json: {},
      answer_key_json: { correct_prediction_choice_id: "pred_e1" },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild, predict])

    first = described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: rebuild.id,
      answer_json: {
        node_ids: %w[n1 n2 n3],
        edge_ids: %w[e1 e2],
        edge_types_by_edge_id: { e1: "causal", e2: "dependency" }
      },
      duration_ms: 20000,
      source_opened_bool: false
    )
    expect(first[:result_code]).to eq("scored")
    expect(first[:session_timer]).to include(:script_version, :elapsed_ms, :remaining_ms)
    expect(SessionPack.find(pack.id).score_frozen_at).to be_nil

    second = described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: predict.id,
      answer_json: { prediction_choice_id: "pred_e1", confidence_0_1: 0.9 },
      duration_ms: 12000,
      source_opened_bool: false
    )

    expect(second[:result_code]).to eq("scored")
    expect(SessionPack.find(pack.id).score_frozen_at).not_to be_nil
  end

  it "returns no-score when source is opened" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 99,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild])

    result = described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: rebuild.id,
      answer_json: {
        node_ids: %w[n1],
        edge_ids: [],
        edge_types_by_edge_id: {}
      },
      duration_ms: 5000,
      source_opened_bool: true
    )

    expect(result[:result_code]).to eq("no_score_source_opened")
  end

  it "enforces canonical script order" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 44,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    predict = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      seed: 45,
      prompt_payload_json: {},
      answer_key_json: { correct_prediction_choice_id: "pred_e1" },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild, predict])

    expect do
      described_class.call(
        user_id: "user_v1",
        session_pack_id: pack.id,
        drill_instance_id: predict.id,
        answer_json: { prediction_choice_id: "pred_e1", confidence_0_1: 0.8 },
        duration_ms: 10_000,
        source_opened_bool: false
      )
    end.to raise_error(ArgumentError, /order violation/)
  end

  it "enforces per-phase duration budget" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 88,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild])

    expect do
      described_class.call(
        user_id: "user_v1",
        session_pack_id: pack.id,
        drill_instance_id: rebuild.id,
        answer_json: {
          node_ids: %w[n1],
          edge_ids: [],
          edge_types_by_edge_id: {}
        },
        duration_ms: 121_000,
        source_opened_bool: false
      )
    end.to raise_error(ArgumentError, /phase budget/)
  end

  it "updates edge mastery for scored attempts touching edges" do
    topic, graph, source_version, rubric = setup_topic_stack
    Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e1",
      from_node_id: "n1",
      to_node_id: "n2",
      edge_type: "causal",
      mechanism_json: { mediator: "n1", observable: "n2", failure_mode: "none", intervention: "check" },
      is_anchor: true,
      schema_version: "1.0.0"
    )
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 66,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1 n2],
        expected_edge_ids: %w[e1],
        expected_edge_types_by_edge_id: { "e1" => "causal" }
      },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild])

    described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: rebuild.id,
      answer_json: {
        node_ids: %w[n1 n2],
        edge_ids: %w[e1],
        edge_types_by_edge_id: { e1: "causal" }
      },
      duration_ms: 30_000,
      source_opened_bool: false
    )

    edge = Edge.find_by!(graph_version_id: graph.id, edge_id: "e1")
    mastery = EdgeMastery.find_by(edge_id: edge.id)
    expect(mastery).not_to be_nil
    expect(mastery.mastery_float).to be > 0.0
    expect(mastery.last_seen_at).not_to be_nil
  end

  it "rejects diagnostics that are not unlocked for current tier" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 101,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    rephrase = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rephrase",
      seed: 102,
      prompt_payload_json: {},
      answer_key_json: { correct_invariant_choice_ids: %w[inv_1] },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild, rephrase])

    expect do
      described_class.call(
        user_id: "user_v1",
        session_pack_id: pack.id,
        drill_instance_id: rephrase.id,
        answer_json: { invariants_selected: %w[inv_1] },
        duration_ms: 10_000,
        source_opened_bool: false
      )
    end.to raise_error(ArgumentError, /locked for tier/)
  end

  it "creates xp events even when workflow_run_id is absent" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 103,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild])

    result = described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: rebuild.id,
      answer_json: {
        node_ids: %w[n1],
        edge_ids: [],
        edge_types_by_edge_id: {}
      },
      duration_ms: 20_000,
      source_opened_bool: false
    )

    xp_event = XpEvent.find(result[:xp_event_id])
    expect(xp_event.workflow_run_id).to eq("session_pack:#{pack.id}")
    expect(result[:progression]).to include(:tier_id, :unlocked_diagnostics)
  end

  it "emits a curvature signal stream entry for high-confidence wrong predict" do
    topic, graph, source_version, rubric = setup_topic_stack
    rebuild = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      seed: 104,
      prompt_payload_json: {},
      answer_key_json: {
        expected_node_ids: %w[n1],
        expected_edge_ids: [],
        expected_edge_types_by_edge_id: {}
      },
      schema_version: "1.0.0"
    )
    predict = DrillInstance.create!(
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      seed: 105,
      prompt_payload_json: {},
      answer_key_json: { correct_prediction_choice_id: "pred_good" },
      schema_version: "1.0.0"
    )
    pack = build_session_pack!(topic: topic, graph: graph, source_version: source_version, rubric: rubric, drills: [rebuild, predict])

    described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: rebuild.id,
      answer_json: {
        node_ids: %w[n1],
        edge_ids: [],
        edge_types_by_edge_id: {}
      },
      duration_ms: 20_000,
      source_opened_bool: false
    )
    result = described_class.call(
      user_id: "user_v1",
      session_pack_id: pack.id,
      drill_instance_id: predict.id,
      answer_json: { prediction_choice_id: "pred_bad", confidence_0_1: 0.95 },
      duration_ms: 20_000,
      source_opened_bool: false
    )

    expect(result[:curvature_pattern_type]).to eq("missing_constraint")
    expect(result[:curvature_stream]).not_to be_empty
  end
end
