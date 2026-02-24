# frozen_string_literal: true

module Workflows
  class CurvatureDiagnostics
    WINDOW_DAYS = 14
    DEDUPE_WINDOW_HOURS = 12
    LOW_BREAK_POINTS = 8
    LOW_PREDICT_POINTS = 5
    HIGH_CONFIDENCE = 0.8

    def self.call(user_id:, topic_id:, attempt:, score:, now: Time.current)
      new(user_id: user_id, topic_id: topic_id, attempt: attempt, score: score, now: now).call
    end

    def initialize(user_id:, topic_id:, attempt:, score:, now:)
      @user_id = user_id
      @topic_id = topic_id
      @attempt = attempt
      @score = score
      @now = now
    end

    def call
      return nil unless score.result_code == "scored"

      signal = detect_missing_constraint || detect_hidden_coupling
      return nil unless signal

      create_once!(signal)
    end

    private

    attr_reader :user_id, :topic_id, :attempt, :score, :now

    def detect_missing_constraint
      return nil unless attempt.diagnostic == "predict"
      return nil unless score.points_total.to_i <= LOW_PREDICT_POINTS

      confidence = answer_value(attempt.answer_json, "confidence_0_1").to_f
      return nil unless confidence >= HIGH_CONFIDENCE

      {
        pattern_type: "missing_constraint",
        evidence_json: {
          "attempt_id" => attempt.id,
          "score_id" => score.id,
          "confidence_0_1" => confidence.round(4),
          "points_total" => score.points_total
        },
        note: "High-confidence incorrect prediction suggests missing constraint checks."
      }
    end

    def detect_hidden_coupling
      return nil unless attempt.diagnostic == "break"
      return nil unless score.points_total.to_i <= LOW_BREAK_POINTS

      cutoff = now - WINDOW_DAYS.days
      rows = Attempt
        .joins(:score)
        .where(user_id: user_id, topic_id: topic_id, diagnostic: "break", scores: { result_code: "scored" })
        .where("attempts.created_at >= ?", cutoff)
        .order(created_at: :desc)
        .limit(5)
      weak_rows = rows.select { |row| row.score.points_total.to_i <= LOW_BREAK_POINTS }
      edge_ids = weak_rows.map { |row| answer_value(row.answer_json, "broken_edge_id").to_s }.reject(&:blank?).uniq
      return nil unless weak_rows.length >= 2 && edge_ids.length >= 2

      {
        pattern_type: "hidden_coupling",
        evidence_json: {
          "attempt_ids" => weak_rows.map(&:id),
          "edges_involved" => edge_ids
        },
        note: "Repeated low break localization across different edges indicates hidden coupling."
      }
    end

    def create_once!(attrs)
      existing = CurvatureSignal
        .where(topic_id: topic_id, pattern_type: attrs.fetch(:pattern_type))
        .where("created_at >= ?", now - DEDUPE_WINDOW_HOURS.hours)
        .find_by(evidence_json: attrs.fetch(:evidence_json))
      return existing if existing

      signal = CurvatureSignal.create!(
        topic_id: topic_id,
        pattern_type: attrs.fetch(:pattern_type),
        evidence_json: attrs.fetch(:evidence_json),
        note: attrs.fetch(:note),
        schema_version: "1.0.0"
      )
      Schemas::Validator.call!(schema_name: "curvature_signal", payload: signal.attributes)
      signal
    end

    def answer_value(json, key)
      return nil unless json.is_a?(Hash)
      return json[key] if json.key?(key)

      json[key.to_sym]
    end
  end
end
