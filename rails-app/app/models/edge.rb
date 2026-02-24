# frozen_string_literal: true

class Edge < ApplicationRecord
  belongs_to :graph_version
  has_many :edge_evidences, foreign_key: :edge_id, primary_key: :id, dependent: :destroy

  EDGE_TYPES = %w[causal constraint tradeoff dependency].freeze
  MAX_PER_GRAPH = 18
  MAX_ANCHOR_PER_GRAPH = 10

  validates :edge_id, :from_node_id, :to_node_id, :edge_type, presence: true
  validates :edge_type, inclusion: { in: EDGE_TYPES }
  validate :graph_edge_cap_not_exceeded
  validate :anchor_edge_cap_not_exceeded, if: :is_anchor?

  private

  def graph_edge_cap_not_exceeded
    return unless graph_version

    existing_count = graph_version.edges.where.not(id: id).count
    return unless existing_count >= MAX_PER_GRAPH

    errors.add(:base, "Graph edge cap exceeded (max #{MAX_PER_GRAPH})")
  end

  def anchor_edge_cap_not_exceeded
    return unless graph_version

    existing_anchor_count = graph_version.edges.where(is_anchor: true).where.not(id: id).count
    return unless existing_anchor_count >= MAX_ANCHOR_PER_GRAPH

    errors.add(:base, "Anchor edge cap exceeded (max #{MAX_ANCHOR_PER_GRAPH})")
  end
end
