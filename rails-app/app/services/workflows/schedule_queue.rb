# frozen_string_literal: true

require "set"

module Workflows
  class ScheduleQueue
    def self.call(user_id:, now: Time.current)
      topics = Topic.where(user_id: user_id).order(:id).to_a
      return { selected_topic_id: nil, queue: [] } if topics.empty?

      schedule_state = Schedule.find_by(user_id: user_id)&.state_json || {}
      topic_ids = topics.map(&:id)

      graph_topic_ids = GraphVersion.where(topic_id: topic_ids).distinct.pluck(:topic_id).to_set
      source_ids = topics.map(&:source_id).compact
      source_ids_with_versions = SourceVersion.where(source_id: source_ids).distinct.pluck(:source_id).to_set

      curvature_by_topic = recent_curvature_by_topic(topic_ids: topic_ids, now: now)

      payload_topics = topics.map do |topic|
        {
          topic_id: topic.id,
          has_graph_version: graph_topic_ids.include?(topic.id),
          has_source_version: topic.source_id.present? && source_ids_with_versions.include?(topic.source_id),
          updated_at: topic.updated_at&.utc&.iso8601,
          curvature_signal_at: curvature_by_topic[topic.id]&.utc&.iso8601
        }
      end

      Workflows::EngineBridge.build_schedule_queue(
        topics: payload_topics,
        schedule_state: schedule_state,
        now: now.utc.iso8601,
        audit_interval_days: Workflows::RotationPolicy::AUDIT_INTERVAL_DAYS,
        curvature_window_days: Workflows::RotationPolicy::CURVATURE_WINDOW_DAYS
      )
    end

    def self.recent_curvature_by_topic(topic_ids:, now:)
      cutoff = now - Workflows::RotationPolicy::CURVATURE_WINDOW_DAYS.days
      CurvatureSignal
        .where(topic_id: topic_ids)
        .where("created_at >= ?", cutoff)
        .order(created_at: :desc)
        .each_with_object({}) do |signal, memo|
          memo[signal.topic_id] ||= signal.created_at
        end
    end
  end
end
