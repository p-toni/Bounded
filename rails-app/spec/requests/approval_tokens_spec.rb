# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApprovalTokens", type: :routing do
  it "defines approval token route" do
    expect(post: "/approval_tokens").to be_routable
  end
end
