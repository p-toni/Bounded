# frozen_string_literal: true

class WorkflowRun < ApplicationRecord
  WORKFLOW_TYPES = %w[prepare_rep run_reality_audit post_session_debrief evidence_assist render_share_pack].freeze
  STATUSES = %w[queued running waiting_for_input succeeded failed canceled].freeze

  has_many :workflow_step_events, dependent: :destroy
  has_many :tool_call_logs, dependent: :destroy
  has_many :scout_artifacts, dependent: :nullify

  validates :workflow_type, inclusion: { in: WORKFLOW_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, :user_id, presence: true
end
