# frozen_string_literal: true

class Schedule < ApplicationRecord
  validates :user_id, presence: true
end
