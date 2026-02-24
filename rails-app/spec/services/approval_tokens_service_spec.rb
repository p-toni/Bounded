# frozen_string_literal: true

require "rails_helper"

RSpec.describe Security::ApprovalTokens do
  it "issues and consumes token exactly once" do
    issued = described_class.issue(user_id: "user_v1", action: "export", scope: "workspace:all", ttl_minutes: 10)
    expect(issued[:approval_token]).to be_present

    token = described_class.consume!(
      user_id: "user_v1",
      action: "export",
      scope: "workspace:all",
      approval_token: issued[:approval_token]
    )
    expect(token).to be_present
    expect(token.consumed?).to eq(true)

    expect do
      described_class.consume!(
        user_id: "user_v1",
        action: "export",
        scope: "workspace:all",
        approval_token: issued[:approval_token]
      )
    end.to raise_error(ArgumentError)
  end
end
