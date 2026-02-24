# frozen_string_literal: true

require "digest"
require "json"

module Workflows
  class ScoutPostFreeze
    def self.call(user_id:, session_pack_id:, workflow_run_id: nil)
      new(user_id: user_id, session_pack_id: session_pack_id, workflow_run_id: workflow_run_id).call
    end

    def initialize(user_id:, session_pack_id:, workflow_run_id:)
      @user_id = user_id
      @session_pack_id = session_pack_id
      @workflow_run_id = workflow_run_id
    end

    def call
      pack = SessionPack.find(session_pack_id)
      raise ArgumentError, "session pack does not belong to user" unless pack.user_id == user_id
      raise ArgumentError, "scout is allowed only after score freeze" unless pack.score_frozen?

      attempts = Attempt.where(user_id: user_id, drill_instance_id: pack.drill_instance_ids).includes(:score).order(:created_at)
      raise ArgumentError, "no attempts found for session pack" if attempts.empty?

      edges = Edge.where(graph_version_id: pack.graph_version_id).order(:id).to_a
      nodes = Node.where(graph_version_id: pack.graph_version_id).order(:id).to_a
      edge_ids = edges.map { |edge| edge.edge_id.presence || edge.id.to_s }
      node_ids = nodes.map { |node| node.node_id.presence || node.id.to_s }
      raise ArgumentError, "graph has no edges or nodes for scout context" if edge_ids.empty? || node_ids.empty?

      weak_attempts = attempts.map do |attempt|
        points = attempt.score&.points_total.to_i
        max_points = attempt.diagnostic == "rebuild" ? 30 : (attempt.diagnostic == "audit" ? 25 : 20)
        {
          diagnostic: attempt.diagnostic,
          points_total: points,
          points_max: max_points
        }
      end

      llm_result = Llm::OpenaiClient.new.generate_scout(
        "session_pack_id" => pack.id,
        "topic_id" => pack.topic_id,
        "graph_version_id" => pack.graph_version_id,
        "edge_ids" => edge_ids,
        "node_ids" => node_ids,
        "weak_attempts" => weak_attempts
      )
      output = normalize_output(
        llm_result["scout_output"] || llm_result[:scout_output],
        allowed_edge_ids: edge_ids,
        allowed_node_ids: node_ids
      )
      payload_hash = Digest::SHA256.hexdigest(JSON.generate(output))

      artifact = ScoutArtifact.create!(
        session_pack_id: pack.id,
        workflow_run_id: workflow_run_id,
        user_id: user_id,
        output_json: output,
        payload_hash: payload_hash,
        policy_json: {
          policy_decision: llm_result["policy_decision"] || llm_result[:policy_decision] || "allow",
          provider: llm_result["provider"] || llm_result[:provider] || "none",
          model: llm_result["model"] || llm_result[:model] || "unknown",
          cache_key: llm_result["cache_key"] || llm_result[:cache_key],
          redactions_applied_json: llm_result["redactions_applied_json"] || llm_result[:redactions_applied_json] || []
        },
        schema_version: "1.0.0"
      )
      Schemas::Validator.call!(schema_name: "scout_artifact", payload: artifact.attributes)

      {
        scout_artifact_id: artifact.id,
        scout_output: output,
        payload_hash: payload_hash
      }
    end

    private

    attr_reader :user_id, :session_pack_id, :workflow_run_id

    def normalize_output(raw, allowed_edge_ids:, allowed_node_ids:)
      default_edges = allowed_edge_ids.first(2)
      default_nodes = allowed_node_ids.first([3, allowed_node_ids.length].min)
      output = raw.is_a?(Hash) ? raw : {}
      counterexamples = Array(output["counterexamples"] || output[:counterexamples])
      alternate = output["alternate_framing"] || output[:alternate_framing]
      failure_mode = output["failure_mode"] || output[:failure_mode]

      normalized_counterexamples = counterexamples.map do |item|
        next unless item.is_a?(Hash)

        edge_id = item["edge_id"] || item[:edge_id]
        text = item["text"] || item[:text]
        next unless allowed_edge_ids.include?(edge_id.to_s)

        {
          "edge_id" => edge_id.to_s,
          "text" => sanitize_text(text, max_len: 220)
        }
      end.compact.first(2)

      while normalized_counterexamples.length < 2
        fallback_edge = default_edges[normalized_counterexamples.length] || allowed_edge_ids.first
        normalized_counterexamples << {
          "edge_id" => fallback_edge.to_s,
          "text" => "Counterexample for edge #{fallback_edge}: stress a boundary case where the mechanism does not hold."
        }
      end

      alt_hash = alternate.is_a?(Hash) ? alternate : {}
      alt_nodes = Array(alt_hash["node_ids"] || alt_hash[:node_ids]).map(&:to_s).select { |id| allowed_node_ids.include?(id) }.uniq
      alt_nodes = default_nodes if alt_nodes.empty?
      alternate_framing = {
        "node_ids" => alt_nodes,
        "text" => sanitize_text(alt_hash["text"] || alt_hash[:text], max_len: 260)
      }
      if alternate_framing["text"].blank?
        alternate_framing["text"] = "Reframe around invariants on nodes #{alternate_framing['node_ids'].join(', ')} and test if edge assumptions still hold."
      end

      normalized_failure_mode = sanitize_text(failure_mode, max_len: 200)
      if normalized_failure_mode.blank?
        normalized_failure_mode = "Likely failure mode: overconfident edge typing without revalidating evidence spans after patching."
      end

      {
        "counterexamples" => normalized_counterexamples,
        "alternate_framing" => alternate_framing,
        "failure_mode" => normalized_failure_mode
      }
    end

    def sanitize_text(value, max_len:)
      value.to_s.gsub(/\s+/, " ").strip[0, max_len]
    end
  end
end
