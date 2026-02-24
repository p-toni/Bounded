# frozen_string_literal: true

class WorkflowStepEvent < ApplicationRecord
  STEP_STATUSES = %w[started delta completed failed waiting_for_input canceled].freeze

  belongs_to :workflow_run

  validates :step_status, inclusion: { in: STEP_STATUSES }
  validates :step_name, :tool_schema_version, :input_hash, :output_hash, presence: true
end
