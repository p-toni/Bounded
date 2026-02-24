# frozen_string_literal: true

class RetentionCompactionJob < ApplicationJob
  queue_as :workflow_low

  HOT_DAYS = 30

  def perform
    cutoff = HOT_DAYS.days.ago
    old_runs = WorkflowRun.where("updated_at < ?", cutoff).where(status: %w[succeeded failed canceled])

    old_runs.find_each do |run|
      snapshot = Workflows::CompactionSnapshot.call(workflow_run: run)
      next unless Workflows::CompactionSnapshot.verify!(snapshot)

      run.workflow_step_events.where("created_at < ?", cutoff).delete_all
    end
  end
end
