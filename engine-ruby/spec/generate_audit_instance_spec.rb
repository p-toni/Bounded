# frozen_string_literal: true

require_relative "spec_helper"

class GenerateAuditInstanceSpec < Minitest::Test
  MAX_SIGNED_INT32 = 2_147_483_647

  def test_generated_seed_fits_signed_32bit_integer_range
    drill = GeometryGymEngine::Drills::GenerateAuditInstance.call(
      topic_ctx: {
        topic_id: "t1",
        graph_version_id: "gv1",
        source_version_id: "sv1",
        rubric_version_id: "rv1",
        candidate_spans: %w[s1 s2],
        correct_span_ids: %w[s1]
      },
      target_edge_id: "edge_1"
    )

    assert drill[:seed].is_a?(Integer)
    assert_operator drill[:seed], :>=, 0
    assert_operator drill[:seed], :<=, MAX_SIGNED_INT32
  end
end
