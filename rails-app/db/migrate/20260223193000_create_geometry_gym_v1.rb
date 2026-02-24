# frozen_string_literal: true

class CreateGeometryGymV1 < ActiveRecord::Migration[8.0]
  def change
    create_table :sources, id: :string do |t|
      t.string :url, null: false
      t.string :canonical_url
      t.string :title
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :source_versions, id: :string do |t|
      t.string :source_id, null: false
      t.string :content_hash, null: false
      t.text :extracted_text, null: false
      t.text :extracted_html
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :source_spans, id: :string do |t|
      t.string :source_version_id, null: false
      t.string :span_id, null: false
      t.integer :ordinal, null: false
      t.integer :start_char, null: false
      t.integer :end_char, null: false
      t.string :heading
      t.text :text, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :source_spans, [:source_version_id, :span_id], unique: true

    create_table :topics, id: :string do |t|
      t.string :user_id, null: false
      t.string :source_id
      t.string :title, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :graph_versions, id: :string do |t|
      t.string :topic_id, null: false
      t.integer :version_int, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :graph_versions, [:topic_id, :version_int], unique: true

    create_table :nodes, id: :string do |t|
      t.string :graph_version_id, null: false
      t.string :node_id, null: false
      t.string :label, null: false
      t.string :definition_1s, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :nodes, [:graph_version_id, :node_id], unique: true

    create_table :edges, id: :string do |t|
      t.string :graph_version_id, null: false
      t.string :edge_id, null: false
      t.string :from_node_id, null: false
      t.string :to_node_id, null: false
      t.string :edge_type, null: false
      t.jsonb :mechanism_json, null: false, default: {}
      t.boolean :is_anchor, null: false, default: false
      t.integer :audit_passed_count_int, null: false, default: 0
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :edges, [:graph_version_id, :edge_id], unique: true

    create_table :edge_evidence, id: :string do |t|
      t.string :edge_id, null: false
      t.string :source_span_id, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :rubric_versions, id: :string do |t|
      t.string :version, null: false
      t.jsonb :config_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :rubric_versions, :version, unique: true

    create_table :drill_instances, id: :string do |t|
      t.string :topic_id, null: false
      t.string :graph_version_id, null: false
      t.string :source_version_id, null: false
      t.string :rubric_version_id, null: false
      t.string :diagnostic, null: false
      t.integer :seed, null: false
      t.jsonb :prompt_payload_json, null: false, default: {}
      t.jsonb :answer_key_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :drill_instances, [:topic_id, :graph_version_id, :rubric_version_id, :diagnostic, :seed], unique: true, name: "idx_drill_instances_unique_seed"

    create_table :attempts, id: :string do |t|
      t.string :user_id, null: false
      t.string :topic_id, null: false
      t.string :graph_version_id, null: false
      t.string :source_version_id, null: false
      t.string :drill_instance_id, null: false
      t.string :rubric_version_id, null: false
      t.string :diagnostic, null: false
      t.jsonb :answer_json, null: false, default: {}
      t.integer :duration_ms, null: false, default: 0
      t.boolean :source_opened_bool, null: false, default: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :scores, id: :string do |t|
      t.string :attempt_id, null: false
      t.integer :points_total, null: false, default: 0
      t.jsonb :points_by_dimension_json, null: false, default: {}
      t.jsonb :evidence_refs_json, null: false, default: []
      t.string :result_code, null: false, default: "scored"
      t.text :critique_text
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :scores, :attempt_id, unique: true

    create_table :edge_audits, id: :string do |t|
      t.string :edge_id, null: false
      t.string :drill_instance_id, null: false
      t.boolean :passed_bool, null: false, default: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :edge_mastery, id: :string do |t|
      t.string :edge_id, null: false
      t.float :mastery_float, null: false, default: 0.0
      t.datetime :last_seen_at
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :edge_mastery, :edge_id, unique: true

    create_table :topic_scores, id: :string do |t|
      t.string :topic_id, null: false
      t.float :ous_raw_float, null: false, default: 0.0
      t.float :ous_display_float, null: false, default: 0.0
      t.integer :spaced_count_int, null: false, default: 0
      t.string :schema_version, null: false, default: "1.0.0"
      t.datetime :updated_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :topic_scores, :topic_id, unique: true

    create_table :schedules, id: :string do |t|
      t.string :user_id, null: false
      t.jsonb :state_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.datetime :updated_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :schedules, :user_id, unique: true

    create_table :xp_events, id: :string do |t|
      t.string :user_id, null: false
      t.string :topic_id, null: false
      t.string :edge_id
      t.string :workflow_run_id, null: false
      t.integer :base, null: false
      t.float :correctness, null: false
      t.float :novelty, null: false
      t.float :spacing, null: false
      t.integer :xp, null: false
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :curvature_signals, id: :string do |t|
      t.string :topic_id, null: false
      t.string :pattern_type, null: false
      t.jsonb :evidence_json, null: false, default: {}
      t.text :note
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :workflow_runs, id: :string do |t|
      t.string :user_id, null: false
      t.string :workflow_type, null: false
      t.string :status, null: false
      t.string :idempotency_key, null: false
      t.jsonb :input_json, null: false, default: {}
      t.jsonb :bound_versions_json, null: false, default: {}
      t.jsonb :agent_run_state_json, null: false, default: {}
      t.jsonb :error_json
      t.datetime :cancel_requested_at
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :workflow_runs, [:user_id, :workflow_type, :idempotency_key], unique: true, name: "idx_workflow_runs_idem"

    create_table :workflow_step_events, id: :string do |t|
      t.string :workflow_run_id, null: false
      t.string :step_name, null: false
      t.string :step_status, null: false
      t.string :tool_name
      t.jsonb :input_json, null: false, default: {}
      t.jsonb :output_json, null: false, default: {}
      t.jsonb :bound_versions_json, null: false, default: {}
      t.string :input_hash, null: false
      t.string :output_hash, null: false
      t.string :tool_schema_version, null: false
      t.string :step_idempotency_key
      t.datetime :started_at
      t.datetime :finished_at
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :workflow_step_events, [:workflow_run_id, :step_name, :step_idempotency_key], unique: true, where: "step_idempotency_key IS NOT NULL", name: "idx_workflow_step_idem"

    create_table :tool_call_logs, id: :string do |t|
      t.string :workflow_run_id
      t.string :step_event_id
      t.string :tool_name, null: false
      t.jsonb :input_json, null: false, default: {}
      t.jsonb :output_json, null: false, default: {}
      t.jsonb :policy_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :session_packs, id: :string do |t|
      t.string :user_id, null: false
      t.string :topic_id, null: false
      t.string :graph_version_id, null: false
      t.string :source_version_id, null: false
      t.string :rubric_version_id, null: false
      t.jsonb :drill_instance_ids, null: false, default: []
      t.datetime :score_frozen_at
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :debriefs, id: :string do |t|
      t.string :workflow_run_id, null: false
      t.string :user_id, null: false
      t.string :topic_id, null: false
      t.jsonb :summary_json, null: false, default: {}
      t.text :critique_text
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    create_table :share_pack_artifacts, id: :string do |t|
      t.string :workflow_run_id, null: false
      t.string :user_id, null: false
      t.string :topic_id, null: false
      t.string :format, null: false
      t.string :image_path
      t.string :markdown_path
      t.jsonb :payload_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end


    create_table :compaction_snapshots, id: :string do |t|
      t.string :workflow_run_id, null: false
      t.string :payload_hash, null: false
      t.string :signature, null: false
      t.string :storage_path, null: false
      t.integer :event_count, null: false, default: 0
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
    add_index :compaction_snapshots, :workflow_run_id, unique: true

    create_table :approval_tokens, id: :string do |t|
      t.string :user_id, null: false
      t.string :action, null: false
      t.string :scope, null: false
      t.string :resource_id
      t.string :token_hash, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end
  end
end
