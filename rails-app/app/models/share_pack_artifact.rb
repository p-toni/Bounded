# frozen_string_literal: true

class SharePackArtifact < ApplicationRecord
  belongs_to :workflow_run
  belongs_to :topic

  validates :format, presence: true
end
