# frozen_string_literal: true

require "digest"

module GeometryGymEngine
  module Drills
    module AnswerKeyBuilder
      module_function

      def build(diagnostic:, topic_ctx:, seed:)
        case diagnostic.to_s
        when "rebuild" then rebuild_key(topic_ctx: topic_ctx, seed: seed)
        when "rephrase" then rephrase_key(topic_ctx: topic_ctx, seed: seed)
        when "predict" then predict_key(topic_ctx: topic_ctx, seed: seed)
        when "teach" then teach_key(topic_ctx: topic_ctx, seed: seed)
        when "break" then break_key(topic_ctx: topic_ctx, seed: seed)
        when "audit" then audit_key(topic_ctx: topic_ctx, seed: seed)
        else
          {}
        end
      end

      def rebuild_key(topic_ctx:, seed:)
        nodes = Array(fetch(topic_ctx, :nodes, [])).sort_by { |n| node_id(n).to_s }
        edges = Array(fetch(topic_ctx, :edges, [])).sort_by { |e| edge_id(e).to_s }
        anchor_node_ids = Array(fetch(topic_ctx, :anchor_node_ids, []))
        anchor_edge_ids = Array(fetch(topic_ctx, :anchor_edge_ids, []))

        expected_nodes = if anchor_node_ids.empty?
                           pick_deterministic(nodes.map { |n| node_id(n) }, 5, seed)
                         else
                           pick_deterministic(anchor_node_ids, 7, seed)
                         end

        edge_pool = if anchor_edge_ids.empty?
                      edges.map { |e| edge_id(e) }
                    else
                      anchor_edge_ids
                    end
        expected_edges = pick_deterministic(edge_pool, 10, seed)

        type_by_edge = {}
        expected_edges.each do |eid|
          edge = edges.find { |e| edge_id(e) == eid }
          type_by_edge[eid] = fetch(edge || {}, :edge_type, "dependency")
        end

        {
          expected_node_ids: expected_nodes,
          expected_edge_ids: expected_edges,
          expected_edge_types_by_edge_id: type_by_edge,
          evidence_refs: expected_edges
        }
      end

      def rephrase_key(topic_ctx:, seed:)
        candidates = Array(fetch(topic_ctx, :invariant_choices, []))
        if candidates.empty?
          anchor_nodes = Array(fetch(topic_ctx, :anchor_node_ids, []))
          candidates = anchor_nodes.map { |id| "inv_#{id}" }
        end
        candidates = %w[inv_default] if candidates.empty?

        {
          correct_invariant_choice_ids: pick_deterministic(candidates, [2, candidates.length].min, seed)
        }
      end

      def predict_key(topic_ctx:, seed:)
        choices = Array(fetch(topic_ctx, :predict_choices, []))
        choices = %w[pred_a pred_b pred_c] if choices.empty?

        {
          correct_prediction_choice_id: pick_deterministic(choices, 1, seed).first
        }
      end

      def teach_key(topic_ctx:, seed:)
        edges = Array(fetch(topic_ctx, :edges, [])).sort_by { |e| edge_id(e).to_s }
        candidate_paths = Array(fetch(topic_ctx, :teach_paths, []))

        valid_paths = if candidate_paths.empty?
                        auto_path = pick_deterministic(edges.map { |e| edge_id(e) }, 2, seed)
                        [auto_path]
                      else
                        candidate_paths.map { |path| Array(path) }
                      end

        used_edges = valid_paths.flatten.uniq
        missing_pool = edges.map { |e| edge_id(e) } - used_edges
        expected_missing = pick_deterministic(missing_pool, [2, missing_pool.length].min, seed)

        {
          valid_paths: valid_paths,
          expected_missing_edge_ids: expected_missing
        }
      end

      def break_key(topic_ctx:, seed:)
        edges = Array(fetch(topic_ctx, :edges, [])).sort_by { |e| edge_id(e).to_s }
        anchor_edges = Array(fetch(topic_ctx, :anchor_edge_ids, []))
        edge_pool = anchor_edges.empty? ? edges.map { |e| edge_id(e) } : anchor_edges
        selected_broken = pick_deterministic(edge_pool, 1, seed).first || "edge_default"

        downstream_map = fetch(topic_ctx, :downstream_by_edge_id, {})
        downstream = Array(fetch(downstream_map, selected_broken, []))
        if downstream.empty?
          edge = edges.find { |e| edge_id(e) == selected_broken }
          downstream = [fetch(edge || {}, :to_node_id, "node_default")]
        end

        repair_choices = Array(fetch(topic_ctx, :repair_choices, []))
        repair_choices = ["repair_#{selected_broken}"] if repair_choices.empty?

        {
          broken_edge_id: selected_broken,
          downstream_nodes_expected: downstream.uniq,
          correct_repair_choice_id: pick_deterministic(repair_choices, 1, seed).first
        }
      end

      def audit_key(topic_ctx:, seed:)
        correct = Array(fetch(topic_ctx, :correct_span_ids, []))
        candidates = Array(fetch(topic_ctx, :candidate_spans, []))
        correct = pick_deterministic(candidates, [2, candidates.length].min, seed) if correct.empty?
        correct = ["span_default"] if correct.empty?

        {
          correct_span_ids: correct,
          acceptable_sets: [correct]
        }
      end

      def pick_deterministic(items, count, seed)
        normalized = Array(items).compact.map(&:to_s).uniq
        ordered = normalized.sort_by { |item| Digest::SHA256.hexdigest("#{seed}:#{item}") }
        ordered.first([count, ordered.length].min)
      end

      def node_id(node)
        fetch(node, :node_id, fetch(node, :id, nil))
      end

      def edge_id(edge)
        fetch(edge, :edge_id, fetch(edge, :id, nil))
      end

      def fetch(hash, key, default = nil)
        return default unless hash
        return hash[key] if hash.respond_to?(:key?) && hash.key?(key)

        string_key = key.to_s
        return hash[string_key] if hash.respond_to?(:key?) && hash.key?(string_key)

        default
      end
    end
  end
end
