# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::OpenaiClient do
  it "falls back deterministically when api key is missing" do
    client = described_class.new(api_key: nil)
    out = client.generate_critique("topic_id" => "t1", "evidence_refs" => ["e1"])

    expect(out[:policy_decision]).to eq("fallback")
    expect(out[:payload_hash]).to be_present
    expect(out[:critique_text]).to be_present
  end

  it "returns ranked candidates in fallback path" do
    client = described_class.new(api_key: nil)
    out = client.suggest_evidence("edge_id" => "e1", "candidate_span_ids" => %w[s1 s2 s3])

    expect(out[:policy_decision]).to eq("fallback")
    expect(out[:ranked_span_candidates]).to eq(%w[s1 s2 s3])
  end
end
