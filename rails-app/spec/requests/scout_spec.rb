# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scout", type: :routing do
  it "defines scout route" do
    expect(post: "/session_packs/pack_1/scout").to be_routable
  end
end
