# frozen_string_literal: true

require "digest"
require "json"

module GeometryGymEngine
  module Replay
    module ReplayWorkflow
      module_function

      def call(workflow_run:, step_events:)
        issues = []
        sorted = step_events.sort_by { |e| e[:created_at].to_s }

        sorted.each do |event|
          input_hash = sha(event[:input_json])
          output_hash = sha(event[:output_json])
          issues << "Input hash mismatch on #{event[:id]}" if event[:input_hash] && event[:input_hash] != input_hash
          issues << "Output hash mismatch on #{event[:id]}" if event[:output_hash] && event[:output_hash] != output_hash
        end

        {
          pass: issues.empty?,
          issues: issues,
          workflow_run_id: workflow_run[:id]
        }
      end

      def sha(payload)
        Digest::SHA256.hexdigest(JSON.generate(payload || {}))
      end
    end
  end
end
