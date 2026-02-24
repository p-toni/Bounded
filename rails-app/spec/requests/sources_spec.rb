# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sources", type: :routing do
  it "defines source ingest and source show routes" do
    expect(post: "/sources/ingest").to be_routable
    expect(get: "/sources/source_1").to be_routable
  end
end
