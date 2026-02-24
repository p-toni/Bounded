# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TopicScores", type: :routing do
  it "defines topic score route" do
    expect(get: "/topics/topic_1/score").to be_routable
  end
end
