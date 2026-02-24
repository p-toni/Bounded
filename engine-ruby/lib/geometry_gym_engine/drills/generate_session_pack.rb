# frozen_string_literal: true

require "digest"

module GeometryGymEngine
  module Drills
    module GenerateSessionPack
      module_function

      DEFAULT_ROTATION = ["rebuild", "predict", "break"].freeze
      MAX_SIGNED_INT32 = 2_147_483_647

      def call(topic_ctx:, rotation: DEFAULT_ROTATION, rubric_version_id:)
        graph_version_id = topic_ctx.fetch(:graph_version_id)
        source_version_id = topic_ctx.fetch(:source_version_id)
        topic_id = topic_ctx.fetch(:topic_id)
        user_id = topic_ctx.fetch(:user_id)
        provided_answer_keys = topic_ctx.fetch(:answer_keys, {})

        diagnostics = normalized_rotation(rotation)
        drills = diagnostics.map.with_index do |diagnostic, i|
          seed = deterministic_seed(topic_id, graph_version_id, diagnostic, i)
          default_key = GeometryGymEngine::Drills::AnswerKeyBuilder.build(
            diagnostic: diagnostic,
            topic_ctx: topic_ctx,
            seed: seed
          )
          answer_key = provided_answer_keys.fetch(diagnostic, default_key)
          {
            id: "dr_#{seed}",
            schema_version: "1.0.0",
            created_at: Time.now.utc.iso8601,
            topic_id: topic_id,
            graph_version_id: graph_version_id,
            source_version_id: source_version_id,
            rubric_version_id: rubric_version_id,
            diagnostic: diagnostic,
            seed: seed,
            prompt_payload_json: { topic_id: topic_id, diagnostic: diagnostic },
            answer_key_json: answer_key
          }
        end

        {
          session_pack: {
            id: "sp_#{deterministic_seed(user_id, topic_id, graph_version_id, "pack")}",
            schema_version: "1.0.0",
            created_at: Time.now.utc.iso8601,
            user_id: user_id,
            topic_id: topic_id,
            graph_version_id: graph_version_id,
            source_version_id: source_version_id,
            rubric_version_id: rubric_version_id,
            drill_instance_ids: drills.map { |d| d[:id] },
            score_frozen_at: nil
          },
          drill_instances: drills
        }
      end

      def deterministic_seed(*parts)
        Digest::SHA256.hexdigest(parts.join(":"))[0, 8].to_i(16) % MAX_SIGNED_INT32
      end

      def normalized_rotation(rotation)
        requested = Array(rotation).map(&:to_s).reject(&:empty?)
        requested.unshift("rebuild") unless requested.include?("rebuild")
        requested.uniq.first(4)
      end
    end
  end
end
