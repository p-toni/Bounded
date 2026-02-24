# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::Progression do
  def create_attempt_with_score!(user_id:, topic_id:, graph_version_id:, source_version_id:, rubric_version_id:, diagnostic:, points_total:, seed:)
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
      answer_json: {},
      duration_ms: 1000,
      source_opened_bool: false,
      schema_version: "1.0.0"
    )
    Score.create!(
      attempt_id: attempt.id,
      points_total: points_total,
      points_by_dimension_json: {},
      evidence_refs_json: [],
      result_code: "scored",
      schema_version: "1.0.0"
    )
  end

  def create_xp!(user_id:, topic_id:, workflow_run_id:, xp:)
    XpEvent.create!(
      user_id: user_id,
      topic_id: topic_id,
      edge_id: nil,
      workflow_run_id: workflow_run_id,
      base: 20,
      correctness: 1.0,
      novelty: 1.0,
      spacing: 1.0,
      xp: xp,
      schema_version: "1.0.0"
    )
  end

  def setup_topic_stack
    source = Source.create!(url: "https://example.com/progression")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "h-progression",
      extracted_text: "Body",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Progression topic", source_id: source.id)
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "v1", schema_version: "1.0.0")
    [topic, graph, source_version, rubric]
  end

  it "starts at tier 0 with geometry-first diagnostics unlocked" do
    topic, = setup_topic_stack
    snapshot = described_class.snapshot(user_id: "user_v1", topic_id: topic.id)

    expect(snapshot[:tier_id]).to eq(0)
    expect(snapshot[:unlocked_diagnostics]).to include("rebuild", "predict", "break", "audit")
    expect(snapshot[:unlocked_diagnostics]).not_to include("rephrase", "teach")
  end

  it "unlocks tier 1 when xp and geometry reps thresholds are met" do
    topic, graph, source_version, rubric = setup_topic_stack
    %w[rebuild predict break audit predict break].each_with_index do |diag, idx|
      create_attempt_with_score!(
        user_id: "user_v1",
        topic_id: topic.id,
        graph_version_id: graph.id,
        source_version_id: source_version.id,
        rubric_version_id: rubric.id,
        diagnostic: diag,
        points_total: 15,
        seed: 1000 + idx
      )
    end
    create_xp!(user_id: "user_v1", topic_id: topic.id, workflow_run_id: "w1", xp: 35)
    create_xp!(user_id: "user_v1", topic_id: topic.id, workflow_run_id: "w2", xp: 30)

    snapshot = described_class.snapshot(user_id: "user_v1", topic_id: topic.id)

    expect(snapshot[:tier_id]).to eq(1)
    expect(snapshot[:tier_name]).to eq("map_apprentice")
    expect(snapshot[:graph_level]).to eq(1)
    expect(snapshot[:unlocked_diagnostics]).to include("rephrase")
    expect(snapshot[:unlocked_diagnostics]).not_to include("teach")
  end

  it "unlocks tier 2 when audit and OUS requirements are also met" do
    topic, graph, source_version, rubric = setup_topic_stack
    diagnostics = %w[rebuild predict break audit predict break rephrase predict break audit rebuild break predict rephrase]
    diagnostics.each_with_index do |diag, idx|
      create_attempt_with_score!(
        user_id: "user_v1",
        topic_id: topic.id,
        graph_version_id: graph.id,
        source_version_id: source_version.id,
        rubric_version_id: rubric.id,
        diagnostic: diag,
        points_total: 18,
        seed: 2000 + idx
      )
    end
    create_xp!(user_id: "user_v1", topic_id: topic.id, workflow_run_id: "w3", xp: 90)
    create_xp!(user_id: "user_v1", topic_id: topic.id, workflow_run_id: "w4", xp: 90)
    TopicScore.create!(
      topic_id: topic.id,
      ous_raw_float: 60.0,
      ous_display_float: 50.0,
      spaced_count_int: diagnostics.length,
      schema_version: "1.0.0"
    )
    Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e_a",
      from_node_id: "n1",
      to_node_id: "n2",
      edge_type: "causal",
      mechanism_json: { mediator: "n1", observable: "n2", failure_mode: "none", intervention: "check" },
      is_anchor: true,
      audit_passed_count_int: 1,
      schema_version: "1.0.0"
    )
    Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e_b",
      from_node_id: "n2",
      to_node_id: "n3",
      edge_type: "dependency",
      mechanism_json: { mediator: "n2", observable: "n3", failure_mode: "none", intervention: "check" },
      is_anchor: true,
      audit_passed_count_int: 1,
      schema_version: "1.0.0"
    )

    snapshot = described_class.snapshot(user_id: "user_v1", topic_id: topic.id)

    expect(snapshot[:tier_id]).to eq(2)
    expect(snapshot[:tier_name]).to eq("curvature_operator")
    expect(snapshot[:graph_level]).to eq(2)
    expect(snapshot[:unlocked_diagnostics]).to include("teach")
  end
end
