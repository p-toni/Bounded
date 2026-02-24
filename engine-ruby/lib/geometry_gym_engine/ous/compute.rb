# frozen_string_literal: true

module GeometryGymEngine
  module OUS
    module Compute
      module_function

      MAX_OVERDUE_PENALTY = 0.45

      def call(topic_ctx:)
        arr = topic_ctx.fetch(:arr, 0.0).to_f
        ds = topic_ctx.fetch(:ds, 0.0).to_f
        pa = topic_ctx.fetch(:pa, 0.0).to_f
        bl = topic_ctx.fetch(:bl, 0.0).to_f
        ch = topic_ctx.fetch(:ch, 0.0).to_f
        n = topic_ctx.fetch(:spaced_count, 0).to_i
        overdue_penalty = clamp(topic_ctx.fetch(:overdue_penalty, 0.0).to_f, 0.0, MAX_OVERDUE_PENALTY)

        ous_raw = 100.0 * (0.30 * arr + 0.20 * ds + 0.20 * pa + 0.20 * bl + 0.10 * ch)
        ous_raw *= (1.0 - overdue_penalty)
        confidence = Math.sqrt([n, 10].min / 10.0)
        ous_display = ous_raw * confidence

        {
          ous_raw_float: ous_raw.round(2),
          ous_display_float: ous_display.round(2),
          spaced_count_int: n
        }
      end

      def clamp(value, min, max)
        [[value, min].max, max].min
      end
    end
  end
end
