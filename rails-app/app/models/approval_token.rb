# frozen_string_literal: true

class ApprovalToken < ApplicationRecord
  ACTIONS = %w[export delete external_send].freeze

  validates :action, inclusion: { in: ACTIONS }
  validates :token_hash, :expires_at, :scope, :user_id, presence: true

  def consumed?
    consumed_at.present?
  end
end
