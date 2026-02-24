# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::ScheduleQueue do
  it "builds deterministic queue based on audit cadence and curvature" do
    now = Time.utc(2026, 2, 23, 12, 0, 0)
    user_id = "user_v1"

    source_a = Source.create!(url: "https://example.com/a")
    source_b = Source.create!(url: "https://example.com/b")
    SourceVersion.create!(source_id: source_a.id, content_hash: "h-a", extracted_text: "A", schema_version: "1.0.0")
    SourceVersion.create!(source_id: source_b.id, content_hash: "h-b", extracted_text: "B", schema_version: "1.0.0")

    topic_a = Topic.create!(user_id: user_id, title: "Topic A", source_id: source_a.id, updated_at: now - 1.day, created_at: now - 2.days)
    topic_b = Topic.create!(user_id: user_id, title: "Topic B", source_id: source_b.id, updated_at: now - 1.day, created_at: now - 2.days)
    GraphVersion.create!(topic_id: topic_a.id, version_int: 1, schema_version: "1.0.0")
    GraphVersion.create!(topic_id: topic_b.id, version_int: 1, schema_version: "1.0.0")

    Schedule.create!(
      user_id: user_id,
      state_json: {
        "topics" => {
          topic_a.id => { "last_prepare_at" => "2026-02-22T09:00:00Z", "last_audit_at" => "2026-02-22T09:00:00Z" },
          topic_b.id => { "last_prepare_at" => "2026-02-20T09:00:00Z", "last_audit_at" => "2026-02-19T09:00:00Z" }
        }
      },
      schema_version: "1.0.0"
    )

    CurvatureSignal.create!(
      topic_id: topic_a.id,
      pattern_type: "hidden_coupling",
      evidence_json: {},
      schema_version: "1.0.0",
      created_at: now - 1.hour,
      updated_at: now - 1.hour
    )

    queue = described_class.call(user_id: user_id, now: now)

    expect(queue[:selected_topic_id]).to eq(topic_a.id)
    expect(queue[:queue].map { |item| item[:topic_id] }).to include(topic_a.id, topic_b.id)
    expect(queue[:queue].first[:audit_reason]).to eq("curvature_trigger")
  end
end
