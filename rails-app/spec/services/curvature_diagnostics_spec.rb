# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::CurvatureDiagnostics do
  def setup_topic_stack
    source = Source.create!(url: "https://example.com/curvature")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "h-curvature",
      extracted_text: "Body",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Curvature topic", source_id: source.id)
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "v1", schema_version: "1.0.0")
    [topic, graph, source_version, rubric]
  end

  def create_attempt_and_score!(user_id:, topic_id:, graph_version_id:, source_version_id:, rubric_version_id:, diagnostic:, answer_json:, points_total:, seed:)
    drill = DrillInstance.create!(
      topic_id: topic_id,
      graph_version_id: graph_version_id,
      source_version_id: source_version_id,
      rubric_version_id: rubric_version_id,
      diagnostic: diagnostic,
      seed: seed,
      prompt_payload_json: {},
      answer_key_json: {},
      schema_version: "1.0.0"
    )
    attempt = Attempt.create!(
      user_id: user_id,
      topic_id: topic_id,
      graph_version_id: graph_version_id,
      source_version_id: source_version_id,
      drill_instance_id: drill.id,
      rubric_version_id: rubric_version_id,
      diagnostic: diagnostic,
      answer_json: answer_json,
      duration_ms: 5000,
      source_opened_bool: false,
      schema_version: "1.0.0"
    )
    score = Score.create!(
      attempt_id: attempt.id,
      points_total: points_total,
      points_by_dimension_json: {},
      evidence_refs_json: [],
      result_code: "scored",
      schema_version: "1.0.0"
    )

    [attempt, score]
  end

  it "records missing_constraint for high-confidence wrong predictions" do
    topic, graph, source_version, rubric = setup_topic_stack
    attempt, score = create_attempt_and_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      answer_json: { prediction_choice_id: "pred_x", confidence_0_1: 0.95 },
      points_total: 2,
      seed: 501
    )

    signal = described_class.call(
      user_id: "user_v1",
      topic_id: topic.id,
      attempt: attempt,
      score: score
    )

    expect(signal).not_to be_nil
    expect(signal.pattern_type).to eq("missing_constraint")
    expect(signal.evidence_json["attempt_id"]).to eq(attempt.id)
  end

  it "records hidden_coupling when weak break failures spread across edges" do
    topic, graph, source_version, rubric = setup_topic_stack
    create_attempt_and_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "break",
      answer_json: { broken_edge_id: "e1" },
      points_total: 4,
      seed: 601
    )
    attempt, score = create_attempt_and_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "break",
      answer_json: { broken_edge_id: "e2" },
      points_total: 5,
      seed: 602
    )

    signal = described_class.call(
      user_id: "user_v1",
      topic_id: topic.id,
      attempt: attempt,
      score: score
    )

    expect(signal).not_to be_nil
    expect(signal.pattern_type).to eq("hidden_coupling")
    expect(signal.evidence_json["edges_involved"]).to include("e1", "e2")
  end
end
