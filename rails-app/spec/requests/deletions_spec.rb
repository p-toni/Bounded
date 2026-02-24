# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deletions", type: :routing do
  it "defines deletions route" do
    expect(post: "/deletions").to be_routable
  end
end
