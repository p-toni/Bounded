# frozen_string_literal: true

class ScoutArtifact < ApplicationRecord
  belongs_to :session_pack
  belongs_to :workflow_run, optional: true

  validates :session_pack_id, :user_id, :payload_hash, presence: true
end
