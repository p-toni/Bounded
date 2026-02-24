# frozen_string_literal: true

class SessionPack < ApplicationRecord
  belongs_to :topic
  belongs_to :graph_version
  belongs_to :source_version
  belongs_to :rubric_version
  has_many :scout_artifacts, dependent: :destroy

  def score_frozen?
    score_frozen_at.present?
  end
end
