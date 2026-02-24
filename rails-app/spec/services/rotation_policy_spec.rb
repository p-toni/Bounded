# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::RotationPolicy do
  def setup_topic_stack
    source = Source.create!(url: "https://example.com/rotation")
    topic = Topic.create!(user_id: "user_v1", title: "Rotation topic", source_id: source.id)
    graph = GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
    [topic, graph]
  end

  it "filters locked fluency diagnostics for early-tier users" do
    topic, graph = setup_topic_stack
    now = Time.utc(2026, 2, 24, 10, 0, 0) # Tuesday => teach+break base map

    result = described_class.call(user_id: "user_v1", topic: topic, graph_version: graph, now: now)

    diagnostics = result.fetch(:diagnostics)
    expect(diagnostics).to include("rebuild")
    expect(diagnostics).to include("break")
    expect(diagnostics).not_to include("teach")
  end

  it "allows unlocked diagnostics after tier promotion" do
    topic, graph = setup_topic_stack
    source_version = SourceVersion.create!(
      source_id: topic.source_id,
      content_hash: "h-rotation",
      extracted_text: "Body",
      schema_version: "1.0.0"
    )
    rubric = RubricVersion.create!(version: "v1", schema_version: "1.0.0")

    # Meets tier-1 thresholds: scored attempts + geometry reps + xp
    6.times do |idx|
      diagnostic = %w[rebuild predict break audit predict break][idx]
      drill = DrillInstance.create!(
        topic_id: topic.id,
        graph_version_id: graph.id,
        source_version_id: source_version.id,
        rubric_version_id: rubric.id,
        diagnostic: diagnostic,
        seed: 700 + idx,
        prompt_payload_json: {},
        answer_key_json: {},
        schema_version: "1.0.0"
      )
      attempt = Attempt.create!(
        user_id: "user_v1",
        topic_id: topic.id,
        graph_version_id: graph.id,
        source_version_id: source_version.id,
        drill_instance_id: drill.id,
        rubric_version_id: rubric.id,
        diagnostic: diagnostic,
        answer_json: {},
        duration_ms: 1000,
        source_opened_bool: false,
        schema_version: "1.0.0"
      )
      Score.create!(
        attempt_id: attempt.id,
        points_total: 16,
        points_by_dimension_json: {},
        evidence_refs_json: [],
        result_code: "scored",
        schema_version: "1.0.0"
      )
    end
    XpEvent.create!(
      user_id: "user_v1",
      topic_id: topic.id,
      edge_id: nil,
      workflow_run_id: "rotation-tier-1",
      base: 20,
      correctness: 1.0,
      novelty: 1.0,
      spacing: 1.0,
      xp: 70,
      schema_version: "1.0.0"
    )

    now = Time.utc(2026, 2, 23, 10, 0, 0) # Monday => rephrase+predict
    result = described_class.call(user_id: "user_v1", topic: topic, graph_version: graph, now: now)

    expect(result[:progression][:tier_id]).to be >= 1
    expect(result[:diagnostics]).to include("rephrase")
  end
end
