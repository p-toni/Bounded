# frozen_string_literal: true

require "digest"
require "securerandom"

module Security
  class ApprovalTokens
    DEFAULT_TTL_MINUTES = 15
    MAX_TTL_MINUTES = 120

    def self.issue(user_id:, action:, scope:, resource_id: nil, ttl_minutes: DEFAULT_TTL_MINUTES)
      minutes = Integer(ttl_minutes || DEFAULT_TTL_MINUTES)
      raise ArgumentError, "ttl_minutes must be between 1 and #{MAX_TTL_MINUTES}" unless minutes.between?(1, MAX_TTL_MINUTES)

      plain = SecureRandom.hex(24)
      token = ApprovalToken.create!(
        user_id: user_id,
        action: action,
        scope: scope,
        resource_id: resource_id,
        token_hash: digest(plain),
        expires_at: Time.current + minutes.minutes,
        schema_version: "1.0.0"
      )
      Schemas::Validator.call!(schema_name: "approval_token", payload: token.attributes)

      {
        approval_token: plain,
        approval_token_id: token.id,
        action: token.action,
        scope: token.scope,
        expires_at: token.expires_at.iso8601
      }
    end

    def self.consume!(user_id:, action:, scope:, approval_token:)
      hashed = digest(approval_token.to_s)
      token = ApprovalToken.where(
        user_id: user_id,
        action: action,
        scope: scope,
        token_hash: hashed
      ).order(created_at: :desc).first
      raise ArgumentError, "approval token is invalid" unless token
      raise ArgumentError, "approval token already consumed" if token.consumed?
      raise ArgumentError, "approval token expired" if token.expires_at <= Time.current

      token.update!(consumed_at: Time.current)
      token
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end
  end
end
