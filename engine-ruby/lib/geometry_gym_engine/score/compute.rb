# frozen_string_literal: true

module GeometryGymEngine
  module Score
    module Compute
      module_function

      def call(attempt:, drill_instance:)
        if fetch(attempt, :source_opened_bool)
          return {
            id: "score_#{fetch(attempt, :id)}",
            schema_version: "1.0.0",
            created_at: Time.now.utc.iso8601,
            attempt_id: fetch(attempt, :id),
            points_total: 0,
            points_by_dimension_json: {},
            evidence_refs_json: [],
            result_code: "no_score_source_opened",
            critique_text: nil
          }
        end

        diagnostic = fetch(drill_instance, :diagnostic)
        answer_key = fetch(drill_instance, :answer_key_json, {})
        answer = fetch(attempt, :answer_json, {})
        GeometryGymEngine::Score::ValidateAnswerKey.call!(diagnostic: diagnostic, answer_key: answer_key)

        result = case diagnostic
                 when "rebuild" then score_rebuild(answer, answer_key)
                 when "rephrase" then score_rephrase(answer, answer_key)
                 when "predict" then score_predict(answer, answer_key)
                 when "teach" then score_teach(answer, answer_key)
                 when "break" then score_break(answer, answer_key)
                 when "audit" then score_audit(answer, answer_key)
                 else
                   { points_total: 0, points_by_dimension_json: {} }
                 end

        {
          id: "score_#{fetch(attempt, :id)}",
          schema_version: "1.0.0",
          created_at: Time.now.utc.iso8601,
          attempt_id: fetch(attempt, :id),
          points_total: result.fetch(:points_total),
          points_by_dimension_json: result.fetch(:points_by_dimension_json),
          evidence_refs_json: Array(fetch(answer_key, :evidence_refs, [])),
          result_code: "scored",
          critique_text: nil
        }
      end

      def score_rebuild(answer, key)
        expected_nodes = Array(fetch(key, :expected_node_ids, []))
        expected_edges = Array(fetch(key, :expected_edge_ids, []))
        expected_types = fetch(key, :expected_edge_types_by_edge_id, {})

        actual_nodes = Array(fetch(answer, :node_ids, []))
        actual_edges = Array(fetch(answer, :edge_ids, []))
        actual_types = fetch(answer, :edge_types_by_edge_id, {})

        node_recall = ratio(intersection_count(actual_nodes, expected_nodes), expected_nodes.length)
        edge_recall = ratio(intersection_count(actual_edges, expected_edges), expected_edges.length)

        type_expected_count = expected_types.keys.length
        type_matches = expected_types.count do |edge_id, edge_type|
          fetch(actual_types, edge_id, nil) == edge_type
        end
        type_accuracy = ratio(type_matches, type_expected_count)

        points_coverage = (15.0 * node_recall + 10.0 * edge_recall).round
        points_typing = (5.0 * type_accuracy).round
        total = [points_coverage + points_typing, 30].min

        {
          points_total: total,
          points_by_dimension_json: {
            coverage: points_coverage,
            typing: points_typing
          }
        }
      end

      def score_rephrase(answer, key)
        selected = Array(fetch(answer, :invariants_selected, []))
        correct = Array(fetch(key, :correct_invariant_choice_ids, []))
        precision = ratio(intersection_count(selected, correct), selected.length)
        recall = ratio(intersection_count(selected, correct), correct.length)
        f1 = f1_score(precision, recall)
        points = (15.0 * f1).round

        {
          points_total: points,
          points_by_dimension_json: {
            invariance: points
          }
        }
      end

      def score_predict(answer, key)
        correct_choice = fetch(key, :correct_prediction_choice_id, nil)
        selected_choice = fetch(answer, :prediction_choice_id, nil)
        confidence = fetch(answer, :confidence_0_1, 0.0).to_f
        confidence = clamp(confidence, 0.0, 1.0)

        correct = selected_choice == correct_choice
        points_choice = correct ? 15 : 0
        points_confidence = if correct
                              (5.0 * confidence).round
                            else
                              (2.0 * (1.0 - confidence)).round
                            end
        total = [points_choice + points_confidence, 20].min

        {
          points_total: total,
          points_by_dimension_json: {
            predictive_power: points_choice,
            calibration: points_confidence
          }
        }
      end

      def score_teach(answer, key)
        given_path = Array(fetch(answer, :path_edge_ids_in_order, []))
        valid_paths = Array(fetch(key, :valid_paths, []))
        expected_missing = Array(fetch(key, :expected_missing_edge_ids, []))
        given_missing = Array(fetch(answer, :missing_edge_ids, []))

        path_exact = valid_paths.any? { |path| path == given_path }
        path_points = path_exact ? 14 : (10.0 * best_path_overlap(given_path, valid_paths)).round

        missing_precision = ratio(intersection_count(given_missing, expected_missing), given_missing.length)
        missing_recall = ratio(intersection_count(given_missing, expected_missing), expected_missing.length)
        missing_points = (6.0 * f1_score(missing_precision, missing_recall)).round

        total = [path_points + missing_points, 20].min
        {
          points_total: total,
          points_by_dimension_json: {
            teach_path: path_points,
            teach_missing: missing_points
          }
        }
      end

      def score_break(answer, key)
        correct_broken = fetch(key, :broken_edge_id, nil)
        selected_broken = fetch(answer, :broken_edge_id, nil)
        expected_downstream = Array(fetch(key, :downstream_nodes_expected, []))
        selected_downstream = Array(fetch(answer, :downstream_nodes_affected, []))
        correct_repair = fetch(key, :correct_repair_choice_id, nil)
        selected_repair = fetch(answer, :repair_choice_id, nil)

        broken_points = selected_broken == correct_broken ? 10 : 0
        downstream_precision = ratio(intersection_count(selected_downstream, expected_downstream), selected_downstream.length)
        downstream_recall = ratio(intersection_count(selected_downstream, expected_downstream), expected_downstream.length)
        downstream_points = (5.0 * f1_score(downstream_precision, downstream_recall)).round
        repair_points = selected_repair == correct_repair ? 5 : 0

        total = [broken_points + downstream_points + repair_points, 20].min
        {
          points_total: total,
          points_by_dimension_json: {
            localization: broken_points + downstream_points,
            repair: repair_points
          }
        }
      end

      def score_audit(answer, key)
        selected = Array(fetch(answer, :selected_span_ids, []))
        correct = Array(fetch(key, :correct_span_ids, []))
        acceptable_sets = Array(fetch(key, :acceptable_sets, []))

        exact = selected.sort == correct.sort
        accepted_alt = acceptable_sets.any? { |set| Array(set).sort == selected.sort }

        points = if exact || accepted_alt
                   25
                 else
                   precision = ratio(intersection_count(selected, correct), selected.length)
                   recall = ratio(intersection_count(selected, correct), correct.length)
                   (15.0 * f1_score(precision, recall)).round
                 end

        {
          points_total: points,
          points_by_dimension_json: {
            grounding: points
          }
        }
      end

      def fetch(hash, key, default = nil)
        return default unless hash
        return hash[key] if hash.key?(key)

        string_key = key.to_s
        return hash[string_key] if hash.key?(string_key)

        default
      end

      def intersection_count(a, b)
        (Array(a) & Array(b)).length
      end

      def ratio(numerator, denominator)
        return 0.0 if denominator.to_i <= 0

        numerator.to_f / denominator.to_f
      end

      def f1_score(precision, recall)
        return 0.0 if precision + recall <= 0.0

        (2.0 * precision * recall) / (precision + recall)
      end

      def best_path_overlap(given, valid_paths)
        return 0.0 if given.empty? || valid_paths.empty?

        valid_paths.map do |path|
          overlap = intersection_count(given, path)
          ratio(overlap, [given.length, path.length].max)
        end.max || 0.0
      end

      def clamp(value, min, max)
        [[value, min].max, max].min
      end
    end
  end
end
