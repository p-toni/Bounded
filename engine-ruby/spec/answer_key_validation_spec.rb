# frozen_string_literal: true

require_relative "spec_helper"

class AnswerKeyValidationSpec < Minitest::Test
  def test_missing_required_answer_key_fields_raise
    attempt = {
      id: "at_invalid",
      source_opened_bool: false,
      answer_json: { "prediction_choice_id" => "p1" }
    }
    drill = {
      diagnostic: "predict",
      answer_key_json: {}
    }

    assert_raises(ArgumentError) do
      GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    end
  end
end
