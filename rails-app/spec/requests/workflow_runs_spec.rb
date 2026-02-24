# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WorkflowRuns", type: :routing do
  it "defines workflow routes" do
    expect(post: "/workflow_runs").to be_routable
    expect(post: "/workflow_runs/1/cancel").to be_routable
    expect(post: "/workflow_runs/1/continue").to be_routable
    expect(get: "/workflow_runs/1/events").to be_routable
    expect(get: "/workflow_runs/1/replay").to be_routable
    expect(get: "/workflow_runs/1/inspector").to be_routable
  end
end
