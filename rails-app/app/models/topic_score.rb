# frozen_string_literal: true

class TopicScore < ApplicationRecord
  belongs_to :topic

  validates :topic_id, presence: true
  validates :spaced_count_int, numericality: { greater_than_or_equal_to: 0 }
  validates :ous_raw_float, :ous_display_float, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
end
