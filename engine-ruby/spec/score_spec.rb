# frozen_string_literal: true

require_relative "spec_helper"

class ScoreSpec < Minitest::Test
  def test_source_opened_forces_no_score
    attempt = {
      id: "at_1",
      source_opened_bool: true,
      answer_json: {},
      user_id: "u1",
      topic_id: "t1"
    }
    drill = { diagnostic: "predict", answer_key_json: { "correct_prediction_choice_id" => "p1" } }

    score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    assert_equal 0, score[:points_total]
    assert_equal "no_score_source_opened", score[:result_code]
  end
end
