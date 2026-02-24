# frozen_string_literal: true

class ToolCallLog < ApplicationRecord
  belongs_to :workflow_run, optional: true
  belongs_to :workflow_step_event, foreign_key: :step_event_id, optional: true

  validates :tool_name, presence: true
end
