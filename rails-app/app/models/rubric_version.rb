# frozen_string_literal: true

class RubricVersion < ApplicationRecord
  validates :version, presence: true
end
