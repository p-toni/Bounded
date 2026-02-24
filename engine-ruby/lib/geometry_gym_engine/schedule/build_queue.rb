# frozen_string_literal: true

require "json"
require "time"

module GeometryGymEngine
  module Schedule
    class BuildQueue
      DEFAULT_AUDIT_INTERVAL_DAYS = 3
      DEFAULT_CURVATURE_WINDOW_DAYS = 7
      STALE_DAYS_DEFAULT = 10_000

      def self.call(topics:, schedule_state:, now:, audit_interval_days: DEFAULT_AUDIT_INTERVAL_DAYS, curvature_window_days: DEFAULT_CURVATURE_WINDOW_DAYS)
        now_time = parse_time(now) || Time.now.utc
        state_topics = fetch_topics_state(schedule_state)
        window_start = now_time - (curvature_window_days * 86_400)

        ranked = Array(topics).map do |topic|
          topic_id = fetch(topic, :topic_id)&.to_s
          next if topic_id.nil? || topic_id.empty?

          topic_state = state_topics[topic_id] || {}
          last_prepare_at = parse_time(topic_state["last_prepare_at"])
          last_audit_at = parse_time(topic_state["last_audit_at"])
          curvature_signal_at = parse_time(fetch(topic, :curvature_signal_at))

          has_recent_curvature = curvature_signal_at && curvature_signal_at >= window_start
          cadence_due = last_audit_at.nil? || (now_time.to_date - last_audit_at.to_date).to_i >= audit_interval_days
          due_for_audit = !!(cadence_due || has_recent_curvature)

          has_graph_version = fetch(topic, :has_graph_version)
          has_source_version = fetch(topic, :has_source_version)
          eligible = truthy?(has_graph_version, default: true) && truthy?(has_source_version, default: true)

          days_since_prepare = days_since(now_time, last_prepare_at)
          days_since_audit = days_since(now_time, last_audit_at)

          {
            topic_id: topic_id,
            eligible: eligible,
            due_for_audit: due_for_audit,
            audit_reason: has_recent_curvature ? "curvature_trigger" : (cadence_due ? "cadence_due" : nil),
            has_recent_curvature: !!has_recent_curvature,
            days_since_prepare: days_since_prepare,
            days_since_audit: days_since_audit,
            rank_key: [
              eligible ? 0 : 1,
              due_for_audit ? 0 : 1,
              has_recent_curvature ? 0 : 1,
              -(days_since_prepare || STALE_DAYS_DEFAULT),
              -(days_since_audit || STALE_DAYS_DEFAULT),
              topic_id
            ]
          }
        end.compact

        ranked.sort_by! { |item| item[:rank_key] }
        selected = ranked.find { |item| item[:eligible] }

        {
          selected_topic_id: selected&.dig(:topic_id),
          queue: ranked.map do |item|
            item.reject { |k, _| k == :rank_key }
          end
        }
      end

      def self.fetch(topic, key)
        topic[key] || topic[key.to_s]
      end

      def self.fetch_topics_state(schedule_state)
        raw = schedule_state && (schedule_state[:topics] || schedule_state["topics"])
        return {} unless raw.is_a?(Hash)

        raw.each_with_object({}) do |(topic_id, value), memo|
          memo[topic_id.to_s] = deep_stringify(value)
        end
      end

      def self.deep_stringify(obj)
        JSON.parse(JSON.generate(obj || {}))
      end

      def self.parse_time(value)
        return nil if value.nil? || value.to_s.strip.empty?

        Time.iso8601(value.to_s)
      rescue StandardError
        nil
      end

      def self.days_since(now_time, then_time)
        return nil unless then_time

        (now_time.to_date - then_time.to_date).to_i
      end

      def self.truthy?(value, default:)
        return default if value.nil?

        value == true
      end
    end
  end
end
