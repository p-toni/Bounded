# frozen_string_literal: true

class Debrief < ApplicationRecord
  belongs_to :workflow_run
  belongs_to :topic

  validates :user_id, presence: true
end
