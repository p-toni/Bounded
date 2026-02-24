# frozen_string_literal: true

require_relative "spec_helper"

class GenerateSessionPackSpec < Minitest::Test
  MAX_SIGNED_INT32 = 2_147_483_647

  def test_generated_drills_have_valid_answer_keys_and_are_scoreable
    diagnostics_to_check = %w[rebuild rephrase predict teach break]

    diagnostics_to_check.each do |diag|
      rotation = if diag == "predict"
                   %w[rebuild predict break]
                 else
                   ["rebuild", diag, "predict"]
                 end

      result = GeometryGymEngine::Drills::GenerateSessionPack.call(
        topic_ctx: base_topic_ctx,
        rotation: rotation,
        rubric_version_id: "rv1"
      )

      drill = result[:drill_instances].find { |d| d[:diagnostic] == diag }
      refute_nil drill, "Expected drill for diagnostic #{diag}"

      GeometryGymEngine::Score::ValidateAnswerKey.call!(
        diagnostic: drill[:diagnostic],
        answer_key: drill[:answer_key_json]
      )

      attempt = {
        id: "attempt_#{diag}",
        source_opened_bool: false,
        answer_json: answer_for(diagnostic: drill[:diagnostic], answer_key: drill[:answer_key_json])
      }

      score = GeometryGymEngine::Score::Compute.call(attempt: attempt, drill_instance: drill)
      assert_equal "scored", score[:result_code]
      assert score[:points_total] > 0, "Expected non-zero score for #{diag}"
    end
  end

  def test_rotation_normalization_includes_rebuild_and_supports_audit_slot
    result = GeometryGymEngine::Drills::GenerateSessionPack.call(
      topic_ctx: base_topic_ctx,
      rotation: %w[predict break audit],
      rubric_version_id: "rv1"
    )

    diagnostics = result[:drill_instances].map { |d| d[:diagnostic] }
    assert_equal %w[rebuild predict break audit], diagnostics

    audit = result[:drill_instances].find { |d| d[:diagnostic] == "audit" }
    GeometryGymEngine::Score::ValidateAnswerKey.call!(diagnostic: "audit", answer_key: audit[:answer_key_json])
  end

  def test_generated_seeds_fit_signed_32bit_integer_range
    result = GeometryGymEngine::Drills::GenerateSessionPack.call(
      topic_ctx: base_topic_ctx,
      rotation: %w[rebuild predict break audit],
      rubric_version_id: "rv1"
    )

    seeds = result[:drill_instances].map { |d| d[:seed] }
    assert seeds.all? { |seed| seed.is_a?(Integer) && seed >= 0 && seed <= MAX_SIGNED_INT32 }
  end

  private

  def base_topic_ctx
    {
      user_id: "u1",
      topic_id: "t1",
      graph_version_id: "gv1",
      source_version_id: "sv1",
      nodes: [
        { "id" => "n1", "node_id" => "n1", "label" => "A" },
        { "id" => "n2", "node_id" => "n2", "label" => "B" },
        { "id" => "n3", "node_id" => "n3", "label" => "C" }
      ],
      edges: [
        { "id" => "e1", "edge_id" => "e1", "from_node_id" => "n1", "to_node_id" => "n2", "edge_type" => "causal", "is_anchor" => true },
        { "id" => "e2", "edge_id" => "e2", "from_node_id" => "n2", "to_node_id" => "n3", "edge_type" => "dependency", "is_anchor" => true },
        { "id" => "e3", "edge_id" => "e3", "from_node_id" => "n1", "to_node_id" => "n3", "edge_type" => "tradeoff", "is_anchor" => false }
      ],
      anchor_node_ids: %w[n1 n2 n3],
      anchor_edge_ids: %w[e1 e2],
      predict_choices: %w[pred_e1 pred_e2 pred_e3],
      invariant_choices: %w[inv_n1 inv_n2 inv_n3],
      repair_choices: %w[repair_e1 repair_e2 repair_e3],
      downstream_by_edge_id: {
        "e1" => %w[n2 n3],
        "e2" => %w[n3]
      },
      answer_keys: {}
    }
  end

  def answer_for(diagnostic:, answer_key:)
    case diagnostic
    when "rebuild"
      {
        "node_ids" => answer_key[:expected_node_ids] || answer_key["expected_node_ids"],
        "edge_ids" => answer_key[:expected_edge_ids] || answer_key["expected_edge_ids"],
        "edge_types_by_edge_id" => answer_key[:expected_edge_types_by_edge_id] || answer_key["expected_edge_types_by_edge_id"]
      }
    when "rephrase"
      {
        "invariants_selected" => answer_key[:correct_invariant_choice_ids] || answer_key["correct_invariant_choice_ids"],
        "noninvariants_selected" => []
      }
    when "predict"
      {
        "prediction_choice_id" => answer_key[:correct_prediction_choice_id] || answer_key["correct_prediction_choice_id"],
        "confidence_0_1" => 1.0
      }
    when "teach"
      {
        "path_edge_ids_in_order" => (answer_key[:valid_paths] || answer_key["valid_paths"]).first,
        "missing_edge_ids" => answer_key[:expected_missing_edge_ids] || answer_key["expected_missing_edge_ids"]
      }
    when "break"
      {
        "broken_edge_id" => answer_key[:broken_edge_id] || answer_key["broken_edge_id"],
        "downstream_nodes_affected" => answer_key[:downstream_nodes_expected] || answer_key["downstream_nodes_expected"],
        "repair_choice_id" => answer_key[:correct_repair_choice_id] || answer_key["correct_repair_choice_id"]
      }
    else
      {}
    end
  end
end
