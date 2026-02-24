# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module GeometryGym
  module Client
    class ToolClient
      def initialize(base_url:, api_token: nil)
        @base_url = base_url
        @api_token = api_token
      end

      def call_tool(name:, input_json:)
        post_json("/tools/#{name}/call", { input_json: input_json })
      end

      def start_workflow(workflow_type:, input:, idempotency_key:)
        post_json("/workflow_runs", {
          workflow_type: workflow_type,
          input: input,
          idempotency_key: idempotency_key
        })
      end

      def continue_workflow(workflow_run_id:, input_delta:, idempotency_key:)
        post_json("/workflow_runs/#{workflow_run_id}/continue", {
          input_delta: input_delta,
          idempotency_key: idempotency_key
        })
      end

      private

      attr_reader :base_url, :api_token

      def post_json(path, body)
        uri = URI.join(base_url, path)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req["Authorization"] = "Bearer #{api_token}" if api_token
        req.body = JSON.generate(body)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(req)
        end

        JSON.parse(response.body)
      end
    end
  end
end
