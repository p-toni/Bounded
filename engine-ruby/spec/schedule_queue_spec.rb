# frozen_string_literal: true

require "json"
require_relative "spec_helper"

class ScheduleQueueSpec < Minitest::Test
  def test_orders_due_audit_topics_before_regular_topics
    now = Time.utc(2026, 2, 23, 12, 0, 0)
    result = GeometryGymEngine::Schedule::BuildQueue.call(
      topics: [
        { topic_id: "topic_a", has_graph_version: true, has_source_version: true },
        { topic_id: "topic_b", has_graph_version: true, has_source_version: true },
        { topic_id: "topic_c", has_graph_version: true, has_source_version: true }
      ],
      schedule_state: {
        "topics" => {
          "topic_a" => { "last_prepare_at" => "2026-02-22T10:00:00Z", "last_audit_at" => "2026-02-22T10:00:00Z" },
          "topic_b" => { "last_prepare_at" => "2026-02-18T10:00:00Z", "last_audit_at" => "2026-02-18T10:00:00Z" },
          "topic_c" => { "last_prepare_at" => nil, "last_audit_at" => nil }
        }
      },
      now: now.iso8601
    )

    assert_equal "topic_c", result[:selected_topic_id]
    assert_equal %w[topic_c topic_b topic_a], result[:queue].map { |item| item[:topic_id] }
    assert_equal [true, true, false], result[:queue].map { |item| item[:due_for_audit] }
  end

  def test_curvature_trigger_prioritizes_topic_even_when_cadence_not_due
    now = Time.utc(2026, 2, 23, 12, 0, 0)
    result = GeometryGymEngine::Schedule::BuildQueue.call(
      topics: [
        {
          topic_id: "topic_a",
          has_graph_version: true,
          has_source_version: true,
          curvature_signal_at: "2026-02-23T09:00:00Z"
        },
        { topic_id: "topic_b", has_graph_version: true, has_source_version: true }
      ],
      schedule_state: {
        "topics" => {
          "topic_a" => { "last_prepare_at" => "2026-02-22T10:00:00Z", "last_audit_at" => "2026-02-22T10:00:00Z" },
          "topic_b" => { "last_prepare_at" => "2026-02-20T10:00:00Z", "last_audit_at" => "2026-02-20T10:00:00Z" }
        }
      },
      now: now.iso8601
    )

    assert_equal "topic_a", result[:selected_topic_id]
    assert_equal "curvature_trigger", result[:queue].first[:audit_reason]
  end

  def test_fixture_audit_cadence_simulation
    fixture = JSON.parse(File.read(File.expand_path("../../fixtures/goldset/v1/schedule/cadence_simulation.json", __dir__)))
    fixture.fetch("cases").each do |spec_case|
      result = GeometryGymEngine::Schedule::BuildQueue.call(
        topics: spec_case.fetch("topics"),
        schedule_state: spec_case.fetch("schedule_state"),
        now: spec_case.fetch("now"),
        audit_interval_days: spec_case.fetch("audit_interval_days"),
        curvature_window_days: spec_case.fetch("curvature_window_days")
      )

      assert_equal spec_case.fetch("expected_selected_topic_id"), result[:selected_topic_id], spec_case.fetch("name")
      assert_equal spec_case.fetch("expected_queue_order"), result[:queue].map { |item| item[:topic_id] }, spec_case.fetch("name")

      expected_reasons = spec_case.fetch("expected_audit_reason_by_topic")
      actual_reasons = result[:queue].each_with_object({}) do |item, memo|
        memo[item[:topic_id]] = item[:audit_reason]
      end
      assert_equal expected_reasons, actual_reasons, spec_case.fetch("name")
    end
  end
end
