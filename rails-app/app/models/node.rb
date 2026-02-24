# frozen_string_literal: true

class Node < ApplicationRecord
  belongs_to :graph_version

  MAX_PER_GRAPH = 12

  validates :node_id, :label, :definition_1s, presence: true
  validate :graph_node_cap_not_exceeded

  private

  def graph_node_cap_not_exceeded
    return unless graph_version

    existing_count = graph_version.nodes.where.not(id: id).count
    return unless existing_count >= MAX_PER_GRAPH

    errors.add(:base, "Graph node cap exceeded (max #{MAX_PER_GRAPH})")
  end
end
