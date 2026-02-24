# frozen_string_literal: true

module Workflows
  module Definitions
    class EvidenceAssist < Base
      def steps
        [
          :load_edge_and_spans,
          :suggest_evidence_candidates
        ]
      end
    end
  end
end
