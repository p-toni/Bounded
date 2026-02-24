# frozen_string_literal: true

class EdgeMastery < ApplicationRecord
  self.table_name = "edge_mastery"

  belongs_to :edge, foreign_key: :edge_id, primary_key: :id
end
