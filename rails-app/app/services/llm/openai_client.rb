# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "uri"

module Llm
  class OpenaiClient
    RESPONSES_PATH = "/v1/responses"

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", "gpt-5-mini"), base_url: ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com"), timeout_seconds: ENV.fetch("OPENAI_TIMEOUT_SECONDS", "20").to_i)
      @api_key = api_key
      @model = model
      @base_url = base_url
      @timeout_seconds = timeout_seconds
    end

    def generate_critique(input)
      sanitized, redactions = sanitize_critique_input(input)
      payload_hash = Digest::SHA256.hexdigest(JSON.generate(sanitized))
      cache_key = cache_key_for("post_session_debrief", sanitized)

      if api_key.to_s.strip.empty?
        return fallback_critique(payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: "missing_api_key")
      end

      prompt = {
        system: "You are a strict learning debrief assistant. Do not provide scored answers. Provide concise remediation actions using only evidence references provided.",
        user: {
          task: "Generate concise critique text with 2-4 actionable remediation steps.",
          context: sanitized
        }
      }

      text = call_responses(prompt: prompt, cache_key: cache_key)

      {
        critique_text: text,
        provider: "openai",
        model: model,
        cache_key: cache_key,
        policy_decision: "allow",
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    rescue StandardError => e
      fallback_critique(payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: e.message)
    end

    def suggest_evidence(input)
      sanitized, redactions = sanitize_evidence_input(input)
      payload_hash = Digest::SHA256.hexdigest(JSON.generate(sanitized))
      cache_key = cache_key_for("evidence_assist", sanitized)

      if api_key.to_s.strip.empty?
        return fallback_evidence(input: sanitized, payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: "missing_api_key")
      end

      prompt = {
        system: "You rank candidate paragraph spans for a target edge. Return only candidate IDs ordered by strongest evidence.",
        user: {
          task: "Return JSON array ranked_span_candidates with at most 5 span IDs.",
          context: sanitized
        }
      }

      raw_text = call_responses(prompt: prompt, cache_key: cache_key)
      ranked = extract_ranked_span_ids(raw_text, sanitized["candidate_spans"]) 

      {
        ranked_span_candidates: ranked.first(5),
        provider: "openai",
        model: model,
        cache_key: cache_key,
        policy_decision: "allow",
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    rescue StandardError => e
      fallback_evidence(input: sanitized, payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: e.message)
    end

    def generate_scout(input)
      sanitized, redactions = sanitize_scout_input(input)
      payload_hash = Digest::SHA256.hexdigest(JSON.generate(sanitized))
      cache_key = cache_key_for("scout_post_freeze", sanitized)

      if api_key.to_s.strip.empty?
        return fallback_scout(input: sanitized, payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: "missing_api_key")
      end

      prompt = {
        system: "You are a bounded scout assistant. Never provide direct scored answers. Return JSON only with 2 counterexamples (edge_id,text), 1 alternate_framing (node_ids,text), and 1 failure_mode string.",
        user: {
          task: "Generate post-freeze scout output. Use only allowed edge_ids and node_ids.",
          context: sanitized
        }
      }

      raw_text = call_responses(prompt: prompt, cache_key: cache_key)
      parsed = parse_json_object(raw_text)
      output = if parsed && parsed.is_a?(Hash)
                 parsed
               else
                 {}
               end

      {
        scout_output: output,
        provider: "openai",
        model: model,
        cache_key: cache_key,
        policy_decision: "allow",
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    rescue StandardError => e
      fallback_scout(input: sanitized, payload_hash: payload_hash, redactions: redactions, cache_key: cache_key, reason: e.message)
    end

    private

    attr_reader :api_key, :model, :base_url, :timeout_seconds

    def call_responses(prompt:, cache_key:)
      uri = URI.join(base_url, RESPONSES_PATH)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{api_key}"
      req["X-GeometryGym-Cache-Key"] = cache_key

      body = {
        model: model,
        prompt_cache_key: cache_key,
        input: [
          { role: "system", content: [{ type: "text", text: prompt.fetch(:system) }] },
          { role: "user", content: [{ type: "text", text: JSON.generate(prompt.fetch(:user)) }] }
        ],
        max_output_tokens: 350,
        metadata: {
          cache_key: cache_key,
          policy: "bounded_workflow_only"
        }
      }
      req.body = JSON.generate(body)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout_seconds
      http.read_timeout = timeout_seconds

      resp = http.request(req)
      raise "OpenAI error: #{resp.code}" unless resp.code.to_i.between?(200, 299)

      parsed = JSON.parse(resp.body)
      extract_text(parsed)
    end

    def sanitize_critique_input(input)
      allowed = {
        "topic_id" => safe_scalar(input["topic_id"]),
        "low_score_attempt_ids" => Array(input["low_score_attempt_ids"]),
        "next_actions" => Array(input["next_actions"]),
        "evidence_refs" => Array(input["evidence_refs"]).first(20),
        "points_by_dimension" => input["points_by_dimension"].is_a?(Hash) ? input["points_by_dimension"] : {}
      }
      redact_payload(allowed)
    end

    def sanitize_evidence_input(input)
      candidates = Array(input["candidate_spans"] || input["candidate_span_ids"]).first(20)
      normalized_candidates = candidates.map do |c|
        if c.is_a?(Hash)
          {
            "id" => safe_scalar(c["id"] || c[:id]),
            "snippet" => safe_text(c["snippet"] || c[:snippet] || c["text"] || c[:text], max_len: 320)
          }
        else
          { "id" => safe_scalar(c), "snippet" => nil }
        end
      end

      allowed = {
        "edge_id" => safe_scalar(input["edge_id"]),
        "edge_type" => safe_scalar(input["edge_type"]),
        "candidate_spans" => normalized_candidates
      }
      redact_payload(allowed)
    end

    def sanitize_scout_input(input)
      allowed = {
        "session_pack_id" => safe_scalar(input["session_pack_id"]),
        "topic_id" => safe_scalar(input["topic_id"]),
        "graph_version_id" => safe_scalar(input["graph_version_id"]),
        "edge_ids" => Array(input["edge_ids"]).map { |id| safe_scalar(id) }.compact.first(20),
        "node_ids" => Array(input["node_ids"]).map { |id| safe_scalar(id) }.compact.first(20),
        "weak_attempts" => Array(input["weak_attempts"]).first(10).map do |row|
          next unless row.is_a?(Hash)

          {
            "diagnostic" => safe_scalar(row["diagnostic"] || row[:diagnostic]),
            "points_total" => (row["points_total"] || row[:points_total]).to_i,
            "points_max" => (row["points_max"] || row[:points_max]).to_i
          }
        end.compact
      }
      redact_payload(allowed)
    end

    def redact_payload(payload)
      redactions = []
      redacted = deep_dup(payload)

      walk_and_redact!(redacted, redactions)

      [redacted, redactions]
    end

    def walk_and_redact!(obj, redactions, path = [])
      case obj
      when Hash
        obj.each do |k, v|
          obj[k] = walk_and_redact!(v, redactions, path + [k])
        end
      when Array
        obj.map!.with_index { |v, i| walk_and_redact!(v, redactions, path + [i]) }
      when String
        val = obj.dup
        replaced = false

        if val.match?(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)
          val = val.gsub(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i, "[REDACTED_EMAIL]")
          replaced = true
        end

        if val.match?(/\b\d{8,}\b/)
          val = val.gsub(/\b\d{8,}\b/, "[REDACTED_NUMERIC]")
          replaced = true
        end

        if replaced
          redactions << { path: path.map(&:to_s).join("."), rule: "pii_redaction" }
        end

        val
      else
        obj
      end
    end

    def extract_ranked_span_ids(raw_text, candidate_spans)
      candidate_ids = candidate_spans.map { |x| x["id"] }.compact
      begin
        parsed = JSON.parse(raw_text)
        ids = Array(parsed["ranked_span_candidates"] || parsed["ranked_span_ids"])
        ranked = ids.map(&:to_s).select { |id| candidate_ids.include?(id) }
        return ranked unless ranked.empty?
      rescue JSON::ParserError
        nil
      end

      # Fallback extraction by token matching.
      ranked = []
      candidate_ids.each do |id|
        ranked << id if raw_text.include?(id)
      end
      ranked
    end

    def extract_text(parsed)
      txt = parsed["output_text"]
      return txt if txt.is_a?(String) && !txt.empty?

      output = Array(parsed["output"])
      content = output.flat_map { |o| Array(o["content"]) }
      text_blocks = content.select { |c| c["type"] == "output_text" || c["type"] == "text" }
      text = text_blocks.map { |b| b["text"] || b.dig("text", "value") }.compact.join("\n").strip
      return text unless text.empty?

      "No model text output."
    end

    def parse_json_object(text)
      parsed = JSON.parse(text)
      return parsed if parsed.is_a?(Hash)

      nil
    rescue JSON::ParserError
      start_idx = text.index("{")
      end_idx = text.rindex("}")
      return nil unless start_idx && end_idx && end_idx > start_idx

      JSON.parse(text[start_idx..end_idx])
    rescue StandardError
      nil
    end

    def cache_key_for(workflow_name, payload)
      schema_version = payload["schema_version"] || "1.0.0"
      rubric_version = payload["rubric_version"] || "r1"
      policy_version = "v1"
      "#{workflow_name}|#{schema_version}|#{rubric_version}|#{policy_version}"
    end

    def fallback_critique(payload_hash:, redactions:, cache_key:, reason:)
      {
        critique_text: "Deterministic fallback critique: review failed evidence refs, run audit, then patch one edge.",
        provider: "none",
        model: "deterministic-fallback",
        cache_key: cache_key,
        policy_decision: "fallback",
        fallback_reason: reason,
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    end

    def fallback_evidence(input:, payload_hash:, redactions:, cache_key:, reason:)
      ranked = Array(input["candidate_spans"]).map { |c| c["id"] }.compact.first(5)
      {
        ranked_span_candidates: ranked,
        provider: "none",
        model: "deterministic-fallback",
        cache_key: cache_key,
        policy_decision: "fallback",
        fallback_reason: reason,
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    end

    def fallback_scout(input:, payload_hash:, redactions:, cache_key:, reason:)
      edge_ids = Array(input["edge_ids"]).first(2)
      edge_ids = ["edge_default_a", "edge_default_b"] if edge_ids.length < 2
      node_ids = Array(input["node_ids"]).first(3)
      node_ids = ["node_default"] if node_ids.empty?

      {
        scout_output: {
          "counterexamples" => [
            {
              "edge_id" => edge_ids[0].to_s,
              "text" => "Boundary case where mechanism weakens under changed assumptions."
            },
            {
              "edge_id" => edge_ids[1].to_s,
              "text" => "Counterexample that stresses hidden dependency and can invert the expected outcome."
            }
          ],
          "alternate_framing" => {
            "node_ids" => node_ids.map(&:to_s),
            "text" => "Reframe by preserving invariants on selected nodes and re-evaluating edge constraints."
          },
          "failure_mode" => "Likely failure mode: skipping evidence re-check after edits."
        },
        provider: "none",
        model: "deterministic-fallback",
        cache_key: cache_key,
        policy_decision: "fallback",
        fallback_reason: reason,
        redactions_applied_json: redactions,
        payload_hash: payload_hash
      }
    end

    def safe_scalar(v)
      v.nil? ? nil : v.to_s[0, 200]
    end

    def safe_text(v, max_len:)
      return nil if v.nil?

      v.to_s.gsub(/\s+/, " ").strip[0, max_len]
    end

    def deep_dup(obj)
      JSON.parse(JSON.generate(obj))
    end
  end
end
