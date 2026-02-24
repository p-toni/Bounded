# frozen_string_literal: true

module GeometryGymEngine
  module Score
    module ValidateAnswerKey
      module_function

      REQUIRED_KEYS = {
        "rebuild" => %w[expected_node_ids expected_edge_ids expected_edge_types_by_edge_id],
        "rephrase" => %w[correct_invariant_choice_ids],
        "predict" => %w[correct_prediction_choice_id],
        "teach" => %w[valid_paths expected_missing_edge_ids],
        "break" => %w[broken_edge_id downstream_nodes_expected correct_repair_choice_id],
        "audit" => %w[correct_span_ids]
      }.freeze

      def call!(diagnostic:, answer_key:)
        required = REQUIRED_KEYS.fetch(diagnostic.to_s, [])
        return if required.empty?

        missing = required.reject { |k| key?(answer_key, k) }
        return if missing.empty?

        raise ArgumentError, "Missing answer_key fields for #{diagnostic}: #{missing.join(', ')}"
      end

      def key?(hash, key)
        hash.key?(key) || hash.key?(key.to_sym)
      end
    end
  end
end
