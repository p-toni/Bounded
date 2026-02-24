# frozen_string_literal: true

class GraphVersion < ApplicationRecord
  belongs_to :topic
  has_many :nodes, dependent: :destroy
  has_many :edges, dependent: :destroy

  validates :version_int, presence: true
end
