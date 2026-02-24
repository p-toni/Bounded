# frozen_string_literal: true

require "digest"
require "json"
require "openssl"
require "fileutils"

module Workflows
  class CompactionSnapshot
    SNAPSHOT_DIR = Rails.root.join("tmp", "workflow_snapshots")

    def self.call(workflow_run:)
      step_events = workflow_run.workflow_step_events.order(:created_at)
      payload = {
        workflow_run: {
          id: workflow_run.id,
          workflow_type: workflow_run.workflow_type,
          status: workflow_run.status,
          user_id: workflow_run.user_id,
          idempotency_key: workflow_run.idempotency_key,
          bound_versions_json: workflow_run.bound_versions_json,
          created_at: workflow_run.created_at&.iso8601,
          updated_at: workflow_run.updated_at&.iso8601
        },
        step_events: step_events.map do |e|
          {
            id: e.id,
            step_name: e.step_name,
            step_status: e.step_status,
            input_hash: e.input_hash,
            output_hash: e.output_hash,
            tool_schema_version: e.tool_schema_version,
            created_at: e.created_at&.iso8601
          }
        end
      }

      payload_json = JSON.pretty_generate(payload)
      payload_hash = Digest::SHA256.hexdigest(payload_json)
      signature = OpenSSL::HMAC.hexdigest("SHA256", hmac_secret, payload_hash)

      FileUtils.mkdir_p(SNAPSHOT_DIR)
      storage_path = SNAPSHOT_DIR.join("#{workflow_run.id}.json")
      File.write(storage_path, payload_json)

      snapshot = CompactionSnapshot.find_or_initialize_by(workflow_run_id: workflow_run.id)
      snapshot.assign_attributes(
        payload_hash: payload_hash,
        signature: signature,
        storage_path: storage_path.to_s,
        event_count: step_events.count,
        schema_version: "1.0.0"
      )
      snapshot.save!

      snapshot
    end

    def self.verify!(snapshot)
      payload_json = File.read(snapshot.storage_path)
      payload_hash = Digest::SHA256.hexdigest(payload_json)
      return false unless payload_hash == snapshot.payload_hash

      expected_sig = OpenSSL::HMAC.hexdigest("SHA256", hmac_secret, snapshot.payload_hash)
      expected_sig == snapshot.signature
    end

    def self.hmac_secret
      ENV.fetch("WORKFLOW_SNAPSHOT_HMAC_SECRET", "dev-only-change-me")
    end
  end
end
