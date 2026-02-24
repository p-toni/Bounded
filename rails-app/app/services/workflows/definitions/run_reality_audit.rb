# frozen_string_literal: true

module Workflows
  module Definitions
    class RunRealityAudit < Base
      def steps
        [
          :create_audit_drill_instance,
          :wait_for_audit_input,
          :create_audit_attempt,
          :compute_audit_score,
          :record_edge_audit,
          :compute_audit_xp,
          :recompute_schedule,
          :refresh_topic_score
        ]
      end
    end
  end
end
