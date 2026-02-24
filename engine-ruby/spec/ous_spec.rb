# frozen_string_literal: true

require_relative "spec_helper"

class OusSpec < Minitest::Test
  def test_cold_start_confidence_penalty_applies
    result = GeometryGymEngine::OUS::Compute.call(
      topic_ctx: {
        arr: 1.0,
        ds: 1.0,
        pa: 1.0,
        bl: 1.0,
        ch: 1.0,
        spaced_count: 1
      }
    )

    assert_equal 100.0, result[:ous_raw_float]
    assert result[:ous_display_float] < result[:ous_raw_float]
  end

  def test_overdue_penalty_reduces_raw_and_display
    baseline = GeometryGymEngine::OUS::Compute.call(
      topic_ctx: {
        arr: 1.0,
        ds: 1.0,
        pa: 1.0,
        bl: 1.0,
        ch: 1.0,
        spaced_count: 10,
        overdue_penalty: 0.0
      }
    )
    decayed = GeometryGymEngine::OUS::Compute.call(
      topic_ctx: {
        arr: 1.0,
        ds: 1.0,
        pa: 1.0,
        bl: 1.0,
        ch: 1.0,
        spaced_count: 10,
        overdue_penalty: 0.30
      }
    )

    assert_equal 100.0, baseline[:ous_raw_float]
    assert_equal 70.0, decayed[:ous_raw_float]
    assert decayed[:ous_display_float] < baseline[:ous_display_float]
  end
end
