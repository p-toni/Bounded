# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::CompactionSnapshot do
  it "is defined" do
    expect(described_class).to respond_to(:call)
    expect(described_class).to respond_to(:verify!)
  end
end
