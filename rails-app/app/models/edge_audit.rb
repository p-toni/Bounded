# frozen_string_literal: true

class EdgeAudit < ApplicationRecord
  belongs_to :edge, foreign_key: :edge_id, primary_key: :id
  belongs_to :drill_instance
end
