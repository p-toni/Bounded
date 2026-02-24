# frozen_string_literal: true

require_relative "spec_helper"

class XpSpec < Minitest::Test
  def test_audit_gate_zeroes_xp_for_unaudited_edge
    attempt = { id: "a1", user_id: "u1", topic_id: "t1" }
    score = { points_total: 25 }
    evt = GeometryGymEngine::XP::Compute.call(
      attempt: attempt,
      score: score,
      ctx: {
        base: 25,
        points_max: 25,
        novelty_factor: 1.0,
        spacing_factor: 1.0,
        audit_passed_count: 0,
        rewards_edge: true,
        edge_xp_today: 0,
        topic_xp_today: 0,
        workflow_run_id: "wr1"
      }
    )

    assert_equal 0, evt[:xp]
  end
end
