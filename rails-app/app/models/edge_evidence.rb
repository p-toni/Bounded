# frozen_string_literal: true

class EdgeEvidence < ApplicationRecord
  self.table_name = "edge_evidence"

  belongs_to :edge, foreign_key: :edge_id, primary_key: :id

  validates :source_span_id, presence: true
end
