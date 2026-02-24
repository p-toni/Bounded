# frozen_string_literal: true

class WorkflowRunJob < ApplicationJob
  queue_as :workflow_default

  def perform(workflow_run_id)
    Workflows::Gateway.new(workflow_run_id: workflow_run_id).run
  end
end
