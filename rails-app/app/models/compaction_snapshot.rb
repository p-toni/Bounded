# frozen_string_literal: true

class CompactionSnapshot < ApplicationRecord
  belongs_to :workflow_run

  validates :payload_hash, :signature, :storage_path, presence: true
end
