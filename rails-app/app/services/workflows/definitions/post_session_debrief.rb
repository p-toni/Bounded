# frozen_string_literal: true

module Workflows
  module Definitions
    class PostSessionDebrief < Base
      def steps
        [
          :check_score_frozen,
          :load_debrief_context,
          :compile_deterministic_debrief,
          :optional_generate_critique,
          :persist_debrief
        ]
      end
    end
  end
end
