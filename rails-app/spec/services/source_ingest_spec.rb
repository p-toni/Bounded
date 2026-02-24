# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::SourceIngest do
  it "ingests URL into source/source_version/paragraph spans and bootstraps topic graph" do
    allow(Workflows::EngineBridge).to receive(:fetch_url).and_return(
      canonical_url: "https://example.com/article",
      raw_html: "<html><head><title>Example</title></head><body><p>A</p><p>B</p></body></html>"
    )
    allow(Workflows::EngineBridge).to receive(:extract_content).and_return(
      extracted_text: "A paragraph.\n\nB paragraph.",
      title: "Example"
    )
    allow(Workflows::EngineBridge).to receive(:paragraph_spans).and_return(
      [
        { span_id: "span_a", ordinal: 0, start_char: 0, end_char: 11, heading: nil, text: "A paragraph." },
        { span_id: "span_b", ordinal: 1, start_char: 13, end_char: 24, heading: nil, text: "B paragraph." }
      ]
    )

    result = described_class.call(
      user_id: "user_v1",
      url: "https://example.com/article",
      topic_title: "My Topic"
    )

    expect(result[:source_id]).to be_present
    expect(result[:source_version_id]).to be_present
    expect(result[:topic_id]).to be_present
    expect(result[:graph_version_id]).to be_present
    expect(result[:source_span_count]).to eq(2)

    source = Source.find(result[:source_id])
    expect(source.canonical_url).to eq("https://example.com/article")
    expect(source.source_versions.count).to eq(1)
    expect(SourceSpan.where(source_version_id: result[:source_version_id]).count).to eq(2)
  end

  it "handles ASCII-8BIT extracted text when generating paragraph spans" do
    allow(Workflows::EngineBridge).to receive(:fetch_url).and_return(
      canonical_url: "https://example.com/binary",
      raw_html: "<html><body><p>Alpha</p><p>Beta</p></body></html>"
    )
    allow(Workflows::EngineBridge).to receive(:extract_content).and_return(
      extracted_text: "Alpha paragraph.\n\nBeta paragraph.".dup.force_encoding(Encoding::ASCII_8BIT),
      title: "Binary Example"
    )

    result = described_class.call(
      user_id: "user_v1",
      url: "https://example.com/binary",
      topic_title: "Binary Topic"
    )

    spans = SourceSpan.where(source_version_id: result[:source_version_id]).order(:ordinal).to_a
    expect(spans.size).to eq(2)
    expect(spans.first.text).to eq("Alpha paragraph.")
    expect(spans.first.text.encoding).to eq(Encoding::UTF_8)
  end
end
