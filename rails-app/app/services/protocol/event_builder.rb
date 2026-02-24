# frozen_string_literal: true

module Protocol
  class EventBuilder
    EVENT_TYPES = %w[
      run.accepted
      step.started
      step.delta
      step.completed
      run.waiting_for_input
      run.canceled
      run.failed
      run.completed
    ].freeze

    def self.build(run:, event_seq:, event_type:, payload: {})
      raise ArgumentError, "Unknown event_type: #{event_type}" unless EVENT_TYPES.include?(event_type)

      {
        protocol_version: "v1",
        workflow_run_id: run.id,
        workflow_name: run.workflow_type,
        event_seq: event_seq,
        timestamp: Time.current.iso8601,
        event_type: event_type,
        state: run.status,
        cursor: "evt_#{event_seq.to_s.rjust(6, '0')}",
        idempotency_key: run.idempotency_key,
        bound_versions: run.bound_versions_json,
        payload: payload
      }
    end
  end
end
