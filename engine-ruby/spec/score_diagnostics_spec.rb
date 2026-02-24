# frozen_string_literal: true

require_relative "spec_helper"

class ScoreDiagnosticsSpec < Minitest::Test
  def test_predict_scoring_with_confidence
    attempt = {
      id: "at_predict",
      source_opened_bool: false,
      answer_json: { "prediction_choice_id" => "p1", "confidence_0_1" => 0.8 }
    }
    drill = {
      diagnostic: "predict",
      answer_key_json: { "correct_prediction_choice_id" => "p1" }
    }

    score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    assert_equal "scored", score[:result_code]
    assert_equal 19, score[:points_total]
    assert_equal 15, score[:points_by_dimension_json][:predictive_power]
  end

  def test_audit_scoring_with_acceptable_set
    attempt = {
      id: "at_audit",
      source_opened_bool: false,
      answer_json: { "selected_span_ids" => %w[s2 s1] }
    }
    drill = {
      diagnostic: "audit",
      answer_key_json: {
        "correct_span_ids" => %w[s3 s4],
        "acceptable_sets" => [%w[s1 s2]]
      }
    }

    score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    assert_equal 25, score[:points_total]
  end

  def test_break_scoring
    attempt = {
      id: "at_break",
      source_opened_bool: false,
      answer_json: {
        "broken_edge_id" => "e7",
        "downstream_nodes_affected" => %w[n2 n3],
        "repair_choice_id" => "r2"
      }
    }
    drill = {
      diagnostic: "break",
      answer_key_json: {
        "broken_edge_id" => "e7",
        "downstream_nodes_expected" => %w[n2 n4],
        "correct_repair_choice_id" => "r2"
      }
    }

    score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    assert score[:points_total] >= 15
    assert_equal 5, score[:points_by_dimension_json][:repair]
  end

  def test_rebuild_scoring
    attempt = {
      id: "at_rebuild",
      source_opened_bool: false,
      answer_json: {
        "node_ids" => %w[n1 n2],
        "edge_ids" => %w[e1],
        "edge_types_by_edge_id" => { "e1" => "causal" }
      }
    }
    drill = {
      diagnostic: "rebuild",
      answer_key_json: {
        "expected_node_ids" => %w[n1 n2 n3],
        "expected_edge_ids" => %w[e1 e2],
        "expected_edge_types_by_edge_id" => { "e1" => "causal", "e2" => "dependency" }
      }
    }

    score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
    assert score[:points_total] > 0
    assert score[:points_total] <= 30
  end
end
