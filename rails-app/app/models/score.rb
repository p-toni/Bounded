# frozen_string_literal: true

class Score < ApplicationRecord
  RESULT_CODES = %w[scored no_score_source_opened].freeze

  belongs_to :attempt

  validates :result_code, inclusion: { in: RESULT_CODES }
end
