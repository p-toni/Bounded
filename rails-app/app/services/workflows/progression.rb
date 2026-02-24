# frozen_string_literal: true

module Workflows
  class Progression
    GEOMETRY_DIAGNOSTICS = %w[rebuild predict break audit].freeze

    TIER_CONFIG = [
      {
        id: 0,
        name: "edge_scout",
        graph_level: 0,
        unlocked_diagnostics: %w[rebuild predict break audit]
      },
      {
        id: 1,
        name: "map_apprentice",
        graph_level: 1,
        unlocked_diagnostics: %w[rebuild predict break audit rephrase],
        requirements: {
          xp_total_min: 60,
          scored_attempts_min: 6,
          geometry_attempts_min: 4
        }
      },
      {
        id: 2,
        name: "curvature_operator",
        graph_level: 2,
        unlocked_diagnostics: %w[rebuild predict break audit rephrase teach],
        requirements: {
          xp_total_min: 160,
          scored_attempts_min: 14,
          audit_passed_edges_min: 2,
          ous_display_min: 40.0,
          distinct_diagnostics_min: 4
        }
      }
    ].freeze

    def self.snapshot(user_id:, topic_id:, now: Time.current)
      new(user_id: user_id, topic_id: topic_id, now: now).snapshot
    end

    def initialize(user_id:, topic_id:, now:)
      @user_id = user_id
      @topic_id = topic_id
      @now = now
    end

    def snapshot
      metrics = collect_metrics
      tier = evaluate_tier(metrics)
      tier_config = TIER_CONFIG.fetch(tier)
      next_tier_config = TIER_CONFIG.find { |cfg| cfg[:id] == tier + 1 }

      {
        tier_id: tier_config.fetch(:id),
        tier_name: tier_config.fetch(:name),
        graph_level: tier_config.fetch(:graph_level),
        unlocked_diagnostics: tier_config.fetch(:unlocked_diagnostics),
        metrics: metrics,
        next_tier: next_tier_snapshot(next_tier_config, metrics)
      }
    end

    private

    attr_reader :user_id, :topic_id, :now

    def collect_metrics
      scored_scope = Attempt
        .joins(:score)
        .where(user_id: user_id, topic_id: topic_id, scores: { result_code: "scored" })
      scored_attempts = scored_scope.to_a
      scored_attempts_count = scored_attempts.length
      diagnostics = scored_attempts.map(&:diagnostic).uniq
      geometry_attempts_count = scored_attempts.count { |attempt| GEOMETRY_DIAGNOSTICS.include?(attempt.diagnostic) }
      xp_total = XpEvent.where(user_id: user_id, topic_id: topic_id).sum(:xp)
      audit_passed_edges_count = audit_passed_edges_count_for_topic
      ous_display = TopicScore.find_by(topic_id: topic_id)&.ous_display_float.to_f

      {
        scored_attempts_count: scored_attempts_count,
        distinct_diagnostics_count: diagnostics.length,
        geometry_attempts_count: geometry_attempts_count,
        xp_total: xp_total,
        audit_passed_edges_count: audit_passed_edges_count,
        ous_display: ous_display.round(2),
        as_of: now.utc.iso8601
      }
    end

    def evaluate_tier(metrics)
      tier = 0
      TIER_CONFIG.each do |config|
        requirements = config[:requirements]
        next unless requirements_met?(requirements, metrics)

        tier = config.fetch(:id)
      end
      tier
    end

    def requirements_met?(requirements, metrics)
      return true unless requirements

      metrics.fetch(:xp_total) >= requirements.fetch(:xp_total_min, 0) &&
        metrics.fetch(:scored_attempts_count) >= requirements.fetch(:scored_attempts_min, 0) &&
        metrics.fetch(:geometry_attempts_count) >= requirements.fetch(:geometry_attempts_min, 0) &&
        metrics.fetch(:audit_passed_edges_count) >= requirements.fetch(:audit_passed_edges_min, 0) &&
        metrics.fetch(:ous_display) >= requirements.fetch(:ous_display_min, 0.0) &&
        metrics.fetch(:distinct_diagnostics_count) >= requirements.fetch(:distinct_diagnostics_min, 0)
    end

    def next_tier_snapshot(next_tier_config, metrics)
      return nil unless next_tier_config

      requirements = next_tier_config.fetch(:requirements, {})
      {
        tier_id: next_tier_config.fetch(:id),
        tier_name: next_tier_config.fetch(:name),
        requirements: requirements,
        unmet: unmet_requirements(requirements, metrics)
      }
    end

    def unmet_requirements(requirements, metrics)
      unmet = {}
      requirements.each do |key, threshold|
        metric_key = key.to_s.sub(/_min$/, "").to_sym
        current = metrics[metric_key]
        unmet[metric_key] = { current: current, required: threshold } if current.to_f < threshold.to_f
      end
      unmet
    end

    def audit_passed_edges_count_for_topic
      graph_id = GraphVersion.where(topic_id: topic_id).order(version_int: :desc).limit(1).pick(:id)
      return 0 if graph_id.blank?

      Edge.where(graph_version_id: graph_id).where("audit_passed_count_int > 0").count
    end
  end
end
