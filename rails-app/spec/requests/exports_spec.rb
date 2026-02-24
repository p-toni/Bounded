# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Exports", type: :routing do
  it "defines export bundle route" do
    expect(post: "/exports/bundle").to be_routable
  end
end
