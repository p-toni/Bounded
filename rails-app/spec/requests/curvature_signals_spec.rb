# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CurvatureSignals", type: :routing do
  it "defines curvature signal list route" do
    expect(get: "/topics/topic_1/curvature_signals").to be_routable
  end
end
