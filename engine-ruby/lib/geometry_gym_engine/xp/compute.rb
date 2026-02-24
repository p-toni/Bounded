# frozen_string_literal: true

module GeometryGymEngine
  module XP
    module Compute
      module_function

      EDGE_DAILY_CAP = 40
      TOPIC_DAILY_CAP = 120

      def call(attempt:, score:, ctx:)
        base = Integer(ctx.fetch(:base))
        correctness = clamp(score.fetch(:points_total).to_f / [ctx.fetch(:points_max, 25).to_f, 1].max, 0.0, 1.0)
        novelty = clamp(ctx.fetch(:novelty_factor, 1.0).to_f, 0.0, 1.0)
        spacing = clamp(ctx.fetch(:spacing_factor, 1.0).to_f, 0.25, 1.0)
        audit_passed_count = Integer(ctx.fetch(:audit_passed_count, 0))
        rewards_edge = !!ctx.fetch(:rewards_edge, false)

        multiplier = if rewards_edge && audit_passed_count.zero?
                       0.0
                     else
                       novelty * spacing
                     end

        raw_xp = (base * correctness * multiplier).floor
        edge_remaining = [EDGE_DAILY_CAP - Integer(ctx.fetch(:edge_xp_today, 0)), 0].max
        topic_remaining = [TOPIC_DAILY_CAP - Integer(ctx.fetch(:topic_xp_today, 0)), 0].max
        xp = [raw_xp, edge_remaining, topic_remaining].min

        {
          id: "xp_#{attempt.fetch(:id)}",
          schema_version: "1.0.0",
          created_at: Time.now.utc.iso8601,
          user_id: attempt.fetch(:user_id),
          topic_id: attempt.fetch(:topic_id),
          edge_id: ctx[:edge_id],
          workflow_run_id: ctx.fetch(:workflow_run_id),
          base: base,
          correctness: correctness,
          novelty: novelty,
          spacing: spacing,
          xp: xp
        }
      end

      def clamp(value, min, max)
        [[value, min].max, max].min
      end
    end
  end
end
