# frozen_string_literal: true

require "json"
require "time"

module Workflows
  class RotationPolicy
    AUDIT_INTERVAL_DAYS = 3
    CURVATURE_WINDOW_DAYS = 7

    WEEKDAY_DIAGNOSTICS = {
      1 => %w[rephrase predict],
      2 => %w[teach break],
      3 => %w[predict break],
      4 => %w[rephrase teach],
      5 => %w[break rephrase],
      6 => %w[predict teach],
      0 => %w[teach rephrase]
    }.freeze

    def self.call(user_id:, topic:, graph_version:, now: Time.current)
      schedule = Schedule.find_or_initialize_by(user_id: user_id)
      schedule.state_json ||= {}
      state = deep_dup(schedule.state_json)
      topics_state = state["topics"] ||= {}
      topic_state = topics_state[topic.id] ||= {}

      progression = Workflows::Progression.snapshot(user_id: user_id, topic_id: topic.id, now: now)
      unlocked = Array(progression[:unlocked_diagnostics]).map(&:to_s)
      base = WEEKDAY_DIAGNOSTICS.fetch(now.wday, %w[predict teach]).select { |diag| unlocked.include?(diag) }
      if base.length < 2
        fallback_order = %w[predict break rephrase teach]
        fallback = fallback_order.select { |diag| unlocked.include?(diag) && !base.include?(diag) }
        base = (base + fallback).first(2)
      end
      diagnostics = ["rebuild", *base].uniq

      recent_curvature = CurvatureSignal
        .where(topic_id: topic.id)
        .where("created_at >= ?", CURVATURE_WINDOW_DAYS.days.ago)
        .order(created_at: :desc)
        .first

      last_audit_at = parse_time(topic_state["last_audit_at"])
      audit_due = last_audit_at.nil? || (now.to_date - last_audit_at.to_date).to_i >= AUDIT_INTERVAL_DAYS

      audit_required = recent_curvature.present? || audit_due
      audit_reason = if recent_curvature
                       "curvature_trigger"
                     elsif audit_due
                       "cadence_due"
                     end

      audit_target_edge_id = select_audit_edge_id(
        graph_version: graph_version,
        curvature_signal: recent_curvature
      )

      diagnostics << "audit" if audit_required && unlocked.include?("audit")
      diagnostics = diagnostics.uniq.first(4)

      topic_state["last_prepare_at"] = now.utc.iso8601
      topic_state["last_rotation"] = diagnostics
      topic_state["audit_reason"] = audit_reason
      topic_state["tier_id"] = progression[:tier_id]
      topic_state["graph_level"] = progression[:graph_level]
      topic_state["unlocked_diagnostics"] = unlocked
      topics_state[topic.id] = topic_state

      {
        diagnostics: diagnostics,
        audit_required: audit_required,
        audit_reason: audit_reason,
        audit_target_edge_id: audit_target_edge_id,
        progression: progression,
        schedule_state: state
      }
    end

    def self.mark_audit_completed!(user_id:, topic_id:, at: Time.current)
      schedule = Schedule.find_or_initialize_by(user_id: user_id)
      schedule.state_json ||= {}
      topics_state = schedule.state_json["topics"] ||= {}
      topic_state = topics_state[topic_id] ||= {}
      topic_state["last_audit_at"] = at.utc.iso8601
      topics_state[topic_id] = topic_state

      schedule.schema_version ||= "1.0.0"
      schedule.save!
      schedule
    end

    def self.select_audit_edge_id(graph_version:, curvature_signal:)
      edges = graph_version.edges.order(:id)
      return nil if edges.empty?

      if curvature_signal
        involved = Array(curvature_signal.evidence_json.is_a?(Hash) ? curvature_signal.evidence_json["edges_involved"] : nil)
        candidate = edges.find { |e| involved.include?(e.id) || involved.include?(e.edge_id) }
        return candidate.id if candidate
      end

      anchor = edges.find(&:is_anchor)
      (anchor || edges.first).id
    end

    def self.parse_time(value)
      return nil if value.blank?

      Time.iso8601(value)
    rescue StandardError
      nil
    end

    def self.deep_dup(obj)
      JSON.parse(JSON.generate(obj || {}))
    end
  end
end
