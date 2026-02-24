# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::TopicScoreUpdater do
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

  it "updates topic score from deterministic component metrics" do
    source = Source.create!(url: "https://example.com/a")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "h1",
      extracted_text: "A",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Topic", source_id: source.id, schema_version: "1.0.0")
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "v1", schema_version: "1.0.0")

    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      points_total: 24,
      seed: 1001
    )
    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      points_total: 16,
      seed: 1002
    )
    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "break",
      points_total: 12,
      seed: 1003
    )

    score = described_class.call(user_id: "user_v1", topic_id: topic.id)

    expect(score.topic_id).to eq(topic.id)
    expect(score.spaced_count_int).to be >= 3
    expect(score.ous_raw_float).to be_between(0.0, 100.0)
    expect(score.ous_display_float).to be_between(0.0, 100.0)
  end

  it "applies overdue decay from edge mastery last_seen_at" do
    now = Time.utc(2026, 2, 24, 12, 0, 0)
    source = Source.create!(url: "https://example.com/b")
    source_version = SourceVersion.create!(
      source_id: source.id,
      content_hash: "h2",
      extracted_text: "B",
      schema_version: "1.0.0"
    )
    topic = Topic.create!(user_id: "user_v1", title: "Topic B", source_id: source.id, schema_version: "1.0.0")
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    rubric = RubricVersion.create!(version: "v2", schema_version: "1.0.0")
    edge = Edge.create!(
      graph_version_id: graph.id,
      edge_id: "e_overdue",
      from_node_id: "n1",
      to_node_id: "n2",
      edge_type: "causal",
      mechanism_json: { mediator: "n1", observable: "n2", failure_mode: "none", intervention: "check" },
      is_anchor: true,
      schema_version: "1.0.0"
    )
    EdgeMastery.create!(
      edge_id: edge.id,
      mastery_float: 1.0,
      last_seen_at: now,
      schema_version: "1.0.0"
    )

    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "rebuild",
      points_total: 30,
      seed: 2001
    )
    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "predict",
      points_total: 20,
      seed: 2002
    )
    create_attempt_with_score!(
      user_id: "user_v1",
      topic_id: topic.id,
      graph_version_id: graph.id,
      source_version_id: source_version.id,
      rubric_version_id: rubric.id,
      diagnostic: "break",
      points_total: 20,
      seed: 2003
    )

    fresh = described_class.call(user_id: "user_v1", topic_id: topic.id, now: now)
    EdgeMastery.where(edge_id: edge.id).update_all(last_seen_at: now - 45.days)
    overdue = described_class.call(user_id: "user_v1", topic_id: topic.id, now: now)

    expect(fresh.ous_raw_float).to be > overdue.ous_raw_float
    expect(fresh.ous_display_float).to be > overdue.ous_display_float
  end
end
