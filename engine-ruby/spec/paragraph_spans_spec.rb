# frozen_string_literal: true

require_relative "spec_helper"

class ParagraphSpansSpec < Minitest::Test
  def test_deterministic_span_ids
    text = "A first paragraph.\n\nA second paragraph."
    a = GeometryGymEngine::Segment::ParagraphSpans.call(source_version_id: "sv1", extracted_text: text)
    b = GeometryGymEngine::Segment::ParagraphSpans.call(source_version_id: "sv1", extracted_text: text)

    assert_equal a.map { |s| s[:span_id] }, b.map { |s| s[:span_id] }
    assert_equal 2, a.length
  end

  def test_handles_ascii_8bit_text
    text = "First paragraph.\n\nSecond paragraph.".dup.force_encoding(Encoding::ASCII_8BIT)
    spans = GeometryGymEngine::Segment::ParagraphSpans.call(source_version_id: "sv2", extracted_text: text)

    assert_equal 2, spans.length
    assert_equal "First paragraph.", spans[0][:text]
    assert_equal "Second paragraph.", spans[1][:text]
  end
end
