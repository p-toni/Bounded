# frozen_string_literal: true

module GeometryGymEngine
  module Graph
    module ValidateAnchorEvidence
      module_function

      def call(graph_edges:, edge_evidences:)
        evidence_by_edge = edge_evidences.group_by { |row| row[:edge_id] || row["edge_id"] }
        errors = []

        graph_edges.each do |edge|
          is_anchor = edge[:is_anchor] || edge["is_anchor"]
          next unless is_anchor

          edge_id = edge[:id] || edge["id"] || edge[:edge_id] || edge["edge_id"]
          count = evidence_by_edge.fetch(edge_id, []).count
          errors << "Anchor edge #{edge_id} has no evidence spans" if count.zero?
        end

        {
          ok: errors.empty?,
          errors: errors
        }
      end
    end
  end
end
