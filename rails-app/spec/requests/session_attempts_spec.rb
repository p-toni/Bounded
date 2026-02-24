# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session attempts", type: :routing do
  it "defines session attempt route" do
    expect(post: "/session_packs/pack_1/attempts").to be_routable
  end
end
