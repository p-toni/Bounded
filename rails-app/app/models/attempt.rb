# frozen_string_literal: true

class Attempt < ApplicationRecord
  DIAGNOSTICS = %w[rebuild rephrase predict teach break audit].freeze

  belongs_to :topic
  belongs_to :graph_version
  belongs_to :source_version
  belongs_to :drill_instance
  belongs_to :rubric_version
  has_one :score, dependent: :destroy

  validates :user_id, :diagnostic, presence: true
  validates :diagnostic, inclusion: { in: DIAGNOSTICS }
end
