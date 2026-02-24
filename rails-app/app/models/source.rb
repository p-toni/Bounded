# frozen_string_literal: true

class Source < ApplicationRecord
  has_many :source_versions, dependent: :destroy
  has_many :topics, dependent: :nullify

  validates :url, presence: true
end
