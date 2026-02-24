# frozen_string_literal: true

module Workflows
  module Definitions
    class Base
      attr_reader :run

      def initialize(run)
        @run = run
      end

      def steps
        raise NotImplementedError
      end
    end
  end
end
