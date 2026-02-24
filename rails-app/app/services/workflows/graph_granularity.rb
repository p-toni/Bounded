# frozen_string_literal: true

module Workflows
  class GraphGranularity
    MIN_ANCHOR_NODES = 3
    MIN_ANCHOR_EDGES = 5
    LEVEL_CAPS = {
      0 => { max_nodes: 7, max_edges: 10, max_anchor_nodes: 6, max_anchor_edges: 7 },
      1 => { max_nodes: 9, max_edges: 14, max_anchor_nodes: 6, max_anchor_edges: 8 },
      2 => { max_nodes: 12, max_edges: 18, max_anchor_nodes: 7, max_anchor_edges: 10 }
    }.freeze

    def self.validate(graph_version:, progression: nil)
      nodes = graph_version.nodes.to_a
      edges = graph_version.edges.to_a
      anchor_edges = edges.select(&:is_anchor)
      anchor_node_ids = anchor_edges.flat_map { |edge| [edge.from_node_id, edge.to_node_id] }.compact.uniq

      progression_snapshot = progression || Workflows::Progression.snapshot(
        user_id: graph_version.topic.user_id,
        topic_id: graph_version.topic_id
      )
      graph_level = progression_snapshot.fetch(:graph_level, 0).to_i
      active_level = [graph_level, LEVEL_CAPS.keys.max].min
      caps = LEVEL_CAPS.fetch(active_level)

      errors = []
      errors << "Graph has #{nodes.count} nodes (max #{caps.fetch(:max_nodes)} at graph_level #{active_level})" if nodes.count > caps.fetch(:max_nodes)
      errors << "Graph has #{edges.count} edges (max #{caps.fetch(:max_edges)} at graph_level #{active_level})" if edges.count > caps.fetch(:max_edges)
      errors << "Anchor edge count is #{anchor_edges.count} (required #{MIN_ANCHOR_EDGES}-#{caps.fetch(:max_anchor_edges)} at graph_level #{active_level})" if anchor_edges.count < MIN_ANCHOR_EDGES || anchor_edges.count > caps.fetch(:max_anchor_edges)
      errors << "Anchor node count is #{anchor_node_ids.count} (required #{MIN_ANCHOR_NODES}-#{caps.fetch(:max_anchor_nodes)} at graph_level #{active_level})" if anchor_node_ids.count < MIN_ANCHOR_NODES || anchor_node_ids.count > caps.fetch(:max_anchor_nodes)

      {
        ok: errors.empty?,
        errors: errors,
        stats: {
          nodes_count: nodes.count,
          edges_count: edges.count,
          anchor_edges_count: anchor_edges.count,
          anchor_nodes_count: anchor_node_ids.count,
          graph_level: active_level,
          tier_name: progression_snapshot[:tier_name],
          caps: caps
        }
      }
    end
  end
end
