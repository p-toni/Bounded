# frozen_string_literal: true

require "digest"

module GeometryGymEngine
  module Segment
    module ParagraphSpans
      module_function

      def call(source_version_id:, extracted_text:)
        normalized = normalize(extracted_text)
        blocks = normalized.split(/\n{2,}|\r\n{2,}/).map(&:strip).reject(&:empty?)

        spans = []
        offset = 0
        blocks.each_with_index do |block, idx|
          start_char = normalized.index(block, offset) || offset
          end_char = start_char + block.length
          offset = end_char
          span_id = Digest::SHA256.hexdigest("#{source_version_id}:#{idx}:#{block}")[0, 16]

          spans << {
            span_id: span_id,
            ordinal: idx,
            start_char: start_char,
            end_char: end_char,
            heading: nil,
            text: block
          }
        end

        spans
      end

      def normalize(text)
        coerce_utf8(text).unicode_normalize(:nfkc).gsub(/[\t ]+/, " ").gsub(/\r\n?/, "\n").gsub(/\n{3,}/, "\n\n").strip
      end

      def coerce_utf8(text)
        raw = text.to_s.dup
        return "" if raw.empty?

        normalized = if raw.encoding == Encoding::UTF_8
                       raw.scrub
                     else
                       raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
                     end
        normalized.scrub
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        raw.force_encoding(Encoding::UTF_8).scrub
      end
    end
  end
end
