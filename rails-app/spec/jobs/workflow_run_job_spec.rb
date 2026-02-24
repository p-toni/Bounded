# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowRunJob, type: :job do
  it "inherits from ApplicationJob" do
    expect(described_class < ApplicationJob).to eq(true)
  end
end
