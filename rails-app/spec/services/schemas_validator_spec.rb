# frozen_string_literal: true

require "rails_helper"

RSpec.describe Schemas::Validator do
  def base_attempt_payload
    {
      id: "att_1",
      schema_version: "1.0.0",
      created_at: Time.current.utc.iso8601,
      user_id: "user_1",
      topic_id: "topic_1",
      graph_version_id: "graph_1",
      source_version_id: "source_v1",
      drill_instance_id: "drill_1",
      rubric_version_id: "rubric_1",
      diagnostic: "predict",
      answer_json: {
        prediction_choice_id: "pred_1"
      },
      duration_ms: 1000,
      source_opened_bool: false
    }
  end

  it "enforces diagnostic-specific allOf schemas at runtime" do
    expect do
      described_class.call!(schema_name: "attempt", payload: base_attempt_payload)
    end.to raise_error(ArgumentError, /confidence_0_1/)
  end

  it "enforces enum/type constraints at runtime" do
    payload = base_attempt_payload.merge(
      diagnostic: "made_up",
      duration_ms: "1000",
      answer_json: { prediction_choice_id: "pred_1", confidence_0_1: 0.8 }
    )

    expect do
      described_class.call!(schema_name: "attempt", payload: payload)
    end.to raise_error(ArgumentError, /expected one of|expected type/)
  end

  it "ignores rails updated_at when not part of canonical schema" do
    payload = {
      id: "source_1",
      schema_version: "1.0.0",
      created_at: Time.current.utc.iso8601,
      updated_at: Time.current.utc.iso8601,
      url: "https://example.com/article",
      canonical_url: "https://example.com/article",
      title: "Example"
    }

    expect do
      described_class.call!(schema_name: "source", payload: payload)
    end.not_to raise_error
  end

  it "rejects unknown additional properties" do
    payload = {
      id: "source_2",
      schema_version: "1.0.0",
      created_at: Time.current.utc.iso8601,
      url: "https://example.com/other",
      canonical_url: nil,
      title: nil,
      hacked: true
    }

    expect do
      described_class.call!(schema_name: "source", payload: payload)
    end.to raise_error(ArgumentError, /additional property is not allowed/)
  end
end
