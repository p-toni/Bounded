# frozen_string_literal: true

module Workflows
  module Definitions
    class PrepareRep < Base
      def steps
        [
          :resolve_topic,
          :load_latest_versions,
          :validate_anchor_evidence,
          :generate_drill_instances,
          :persist_session_pack
        ]
      end
    end
  end
end
