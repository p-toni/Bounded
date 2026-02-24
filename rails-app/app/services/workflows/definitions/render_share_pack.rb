# frozen_string_literal: true

module Workflows
  module Definitions
    class RenderSharePack < Base
      def steps
        [
          :check_score_frozen,
          :load_frozen_snapshot,
          :render_share_pack,
          :persist_share_pack
        ]
      end
    end
  end
end
