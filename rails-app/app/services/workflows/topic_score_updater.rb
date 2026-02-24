# frozen_string_literal: true

module Workflows
  class TopicScoreUpdater
    MAX_WINDOW = 10
    CURVATURE_WINDOW_DAYS = 14
    OVERDUE_GRACE_DAYS = 3.0
    OVERDUE_RAMP_DAYS = 21.0
    MAX_OVERDUE_PENALTY = 0.45

    def self.call(user_id:, topic_id:, now: Time.current)
      new(user_id: user_id, topic_id: topic_id, now: now).call
    end

    def initialize(user_id:, topic_id:, now:)
      @user_id = user_id
      @topic_id = topic_id
      @now = now
    end

    def call
      attempts = scored_attempts
      metrics = compute_metrics(attempts)

      ous = Workflows::EngineBridge.compute_ous(topic_ctx: metrics)
      record = TopicScore.find_or_initialize_by(topic_id: topic_id)
      record.ous_raw_float = ous.fetch(:ous_raw_float)
      record.ous_display_float = ous.fetch(:ous_display_float)
      record.spaced_count_int = ous.fetch(:spaced_count_int)
      record.schema_version ||= "1.0.0"
      record.save!
      Schemas::Validator.call!(schema_name: "topic_score", payload: record.attributes)
      record
    end

    private

    attr_reader :user_id, :topic_id, :now

    def scored_attempts
      Attempt
        .joins(:score)
        .where(user_id: user_id, topic_id: topic_id, scores: { result_code: "scored" })
        .includes(:score)
        .order(created_at: :desc)
        .limit(MAX_WINDOW)
    end

    def compute_metrics(attempts)
      {
        arr: average_normalized(attempts, "rebuild", max_points: 30.0),
        ds: diagnostic_stability(attempts),
        pa: average_normalized(attempts, "predict", max_points: 20.0),
        bl: average_normalized(attempts, "break", max_points: 20.0),
        ch: curvature_hygiene(attempts),
        spaced_count: attempts.size,
        overdue_penalty: overdue_penalty
      }
    end

    def diagnostic_stability(attempts)
      rephrase = average_normalized(attempts, "rephrase", max_points: 15.0)
      teach = average_normalized(attempts, "teach", max_points: 20.0)
      ((rephrase + teach) / 2.0).round(4)
    end

    def average_normalized(attempts, diagnostic, max_points:)
      selected = attempts.select { |attempt| attempt.diagnostic == diagnostic }
      return 0.0 if selected.empty?

      avg = selected.map { |attempt| attempt.score.points_total.to_f / max_points }.sum / selected.size
      [[avg, 0.0].max, 1.0].min
    end

    def curvature_hygiene(attempts)
      audit_attempts = attempts.select { |attempt| attempt.diagnostic == "audit" }
      audit_component = if audit_attempts.empty?
                          0.5
                        else
                          avg = audit_attempts.map { |attempt| attempt.score.points_total.to_f / 25.0 }.sum / audit_attempts.size
                          [[avg, 0.0].max, 1.0].min
                        end

      recent_curvature_count = CurvatureSignal
        .where(topic_id: topic_id)
        .where("created_at >= ?", now - CURVATURE_WINDOW_DAYS.days)
        .count
      penalty = [recent_curvature_count / 10.0, 0.5].min

      [[audit_component - penalty, 0.0].max, 1.0].min
    end

    def overdue_penalty
      latest_graph_id = GraphVersion.where(topic_id: topic_id).order(version_int: :desc).limit(1).pick(:id)
      return 0.0 if latest_graph_id.blank?

      edge_ids = Edge.where(graph_version_id: latest_graph_id).pluck(:id)
      return 0.0 if edge_ids.empty?

      mastery_rows = EdgeMastery.where(edge_id: edge_ids).where.not(last_seen_at: nil).to_a
      return 0.0 if mastery_rows.empty?

      weighted_sum = 0.0
      weight_total = 0.0
      mastery_rows.each do |row|
        weight = clamp(row.mastery_float.to_f, 0.0, 1.0)
        next if weight <= 0.0

        staleness_days = [(now.to_f - row.last_seen_at.to_f) / 86_400.0, 0.0].max
        overdue_ratio = (staleness_days - OVERDUE_GRACE_DAYS) / OVERDUE_RAMP_DAYS
        edge_penalty = clamp(overdue_ratio, 0.0, 1.0)
        weighted_sum += edge_penalty * weight
        weight_total += weight
      end
      return 0.0 if weight_total <= 0.0

      (MAX_OVERDUE_PENALTY * (weighted_sum / weight_total)).round(4)
    end

    def clamp(value, min, max)
      [[value, min].max, max].min
    end
  end
end
