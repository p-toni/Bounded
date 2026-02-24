# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::Gateway do
  it "defines run method" do
    expect(described_class.instance_methods(false)).to include(:run)
  end
end
