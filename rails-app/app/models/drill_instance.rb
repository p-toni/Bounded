# frozen_string_literal: true

class DrillInstance < ApplicationRecord
  DIAGNOSTICS = %w[rebuild rephrase predict teach break audit].freeze

  belongs_to :topic
  belongs_to :graph_version
  belongs_to :source_version
  belongs_to :rubric_version

  validates :diagnostic, inclusion: { in: DIAGNOSTICS }
  validates :seed, presence: true
end
