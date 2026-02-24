# frozen_string_literal: true

class Topic < ApplicationRecord
  belongs_to :source, optional: true
  has_many :graph_versions, dependent: :destroy
  has_one :topic_score, dependent: :destroy

  validates :user_id, :title, presence: true
end
