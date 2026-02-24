# frozen_string_literal: true

require "digest"
require "json"
require_relative "spec_helper"

class ReplaySpec < Minitest::Test
  def test_replay_hash_checks
    input = { "a" => 1 }
    output = { "b" => 2 }
    event = {
      id: "ev1",
      created_at: "2026-02-23T00:00:00Z",
      input_json: input,
      output_json: output,
      input_hash: Digest::SHA256.hexdigest(JSON.generate(input)),
      output_hash: Digest::SHA256.hexdigest(JSON.generate(output))
    }

    result = GeometryGymEngine::Replay::ReplayWorkflow.call(workflow_run: { id: "wr1" }, step_events: [event])
    assert_equal true, result[:pass]
    assert_empty result[:issues]
  end
end
