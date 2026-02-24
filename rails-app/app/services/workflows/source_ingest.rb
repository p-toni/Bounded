# frozen_string_literal: true

require "digest"

module Workflows
  class SourceIngest
    def self.call(user_id:, url:, topic_title: nil)
      new(user_id: user_id, url: url, topic_title: topic_title).call
    end

    def initialize(user_id:, url:, topic_title:)
      @user_id = user_id
      @url = url
      @topic_title = topic_title
    end

    def call
      fetched = Workflows::EngineBridge.fetch_url(url: url)
      parsed = Workflows::EngineBridge.extract_content(raw_html: fetched.fetch(:raw_html))
      extracted_text = parsed.fetch(:extracted_text).to_s
      raise ArgumentError, "Extracted content is empty" if extracted_text.strip.empty?

      canonical_url = fetched.fetch(:canonical_url).presence || url
      content_hash = Digest::SHA256.hexdigest(extracted_text)

      Source.transaction do
        source = upsert_source(canonical_url: canonical_url, title: parsed[:title])
        source_version, created_source_version = upsert_source_version(
          source: source,
          extracted_text: extracted_text,
          extracted_html: fetched.fetch(:raw_html),
          content_hash: content_hash
        )

        span_count = persist_spans_if_needed(source_version: source_version, extracted_text: extracted_text, force: created_source_version)
        topic, graph_version = upsert_topic_and_graph(source: source, fallback_title: parsed[:title])

        {
          source_id: source.id,
          source_version_id: source_version.id,
          source_span_count: span_count,
          topic_id: topic&.id,
          graph_version_id: graph_version&.id
        }
      end
    end

    private

    attr_reader :user_id, :url, :topic_title

    def upsert_source(canonical_url:, title:)
      source = Source.find_or_initialize_by(canonical_url: canonical_url)
      source.url = url
      source.title = title.presence || source.title
      source.schema_version ||= "1.0.0"
      source.save!
      Schemas::Validator.call!(schema_name: "source", payload: source.attributes)
      source
    end

    def upsert_source_version(source:, extracted_text:, extracted_html:, content_hash:)
      source_version = SourceVersion.find_or_initialize_by(source_id: source.id, content_hash: content_hash)
      created = source_version.new_record?
      if created
        source_version.extracted_text = extracted_text
        source_version.extracted_html = extracted_html
        source_version.schema_version = "1.0.0"
        source_version.save!
      end
      Schemas::Validator.call!(schema_name: "source_version", payload: source_version.attributes)
      [source_version, created]
    end

    def persist_spans_if_needed(source_version:, extracted_text:, force:)
      return source_version.source_spans.count unless force || source_version.source_spans.empty?

      generated = Workflows::EngineBridge.paragraph_spans(
        source_version_id: source_version.id,
        extracted_text: extracted_text
      )

      generated.each do |span|
        record = SourceSpan.find_or_initialize_by(source_version_id: source_version.id, span_id: span.fetch(:span_id))
        record.ordinal = span.fetch(:ordinal)
        record.start_char = span.fetch(:start_char)
        record.end_char = span.fetch(:end_char)
        record.heading = span[:heading]
        record.text = span.fetch(:text)
        record.schema_version ||= "1.0.0"
        record.save!
        Schemas::Validator.call!(schema_name: "source_span", payload: record.attributes)
      end
      generated.count
    end

    def upsert_topic_and_graph(source:, fallback_title:)
      title = topic_title.presence || fallback_title.presence || source.title.presence || source.canonical_url || source.url
      topic = Topic.find_or_create_by!(user_id: user_id, source_id: source.id, title: title) do |t|
        t.schema_version = "1.0.0"
      end

      graph_version = topic.graph_versions.order(version_int: :desc).first
      unless graph_version
        graph_version = GraphVersion.create!(
          topic_id: topic.id,
          version_int: 1,
          schema_version: "1.0.0"
        )
      end
      [topic, graph_version]
    end
  end
end
