# frozen_string_literal: true

require "digest"

module GeometryGymEngine
  module Drills
    module GenerateAuditInstance
      module_function
      MAX_SIGNED_INT32 = 2_147_483_647

      def call(topic_ctx:, target_edge_id:)
        topic_id = topic_ctx.fetch(:topic_id)
        graph_version_id = topic_ctx.fetch(:graph_version_id)
        source_version_id = topic_ctx.fetch(:source_version_id)
        rubric_version_id = topic_ctx.fetch(:rubric_version_id)
        candidates = topic_ctx.fetch(:candidate_spans)
        correct_span_ids = topic_ctx.fetch(:correct_span_ids)
        seed = Digest::SHA256.hexdigest([topic_id, graph_version_id, target_edge_id, "audit"].join(":"))[0, 8].to_i(16) % MAX_SIGNED_INT32

        {
          id: "dr_audit_#{seed}",
          schema_version: "1.0.0",
          created_at: Time.now.utc.iso8601,
          topic_id: topic_id,
          graph_version_id: graph_version_id,
          source_version_id: source_version_id,
          rubric_version_id: rubric_version_id,
          diagnostic: "audit",
          seed: seed,
          prompt_payload_json: {
            audit_type: "edge_to_span",
            edge_id: target_edge_id,
            candidate_span_ids: candidates
          },
          answer_key_json: {
            correct_span_ids: correct_span_ids
          }
        }
      end
    end
  end
end
