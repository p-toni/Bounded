# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_24_132000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "approval_tokens", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "action", null: false
    t.string "scope", null: false
    t.string "resource_id"
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "action", "scope", "token_hash"], name: "idx_approval_tokens_lookup"
  end

  create_table "attempts", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "topic_id", null: false
    t.string "graph_version_id", null: false
    t.string "source_version_id", null: false
    t.string "drill_instance_id", null: false
    t.string "rubric_version_id", null: false
    t.string "diagnostic", null: false
    t.jsonb "answer_json", default: {}, null: false
    t.integer "duration_ms", default: 0, null: false
    t.boolean "source_opened_bool", default: false, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "drill_instance_id"], name: "idx_attempts_user_drill_unique", unique: true
  end

  create_table "compaction_snapshots", id: :string, force: :cascade do |t|
    t.string "workflow_run_id", null: false
    t.string "payload_hash", null: false
    t.string "signature", null: false
    t.string "storage_path", null: false
    t.integer "event_count", default: 0, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workflow_run_id"], name: "index_compaction_snapshots_on_workflow_run_id", unique: true
  end

  create_table "curvature_signals", id: :string, force: :cascade do |t|
    t.string "topic_id", null: false
    t.string "pattern_type", null: false
    t.jsonb "evidence_json", default: {}, null: false
    t.text "note"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "debriefs", id: :string, force: :cascade do |t|
    t.string "workflow_run_id", null: false
    t.string "user_id", null: false
    t.string "topic_id", null: false
    t.jsonb "summary_json", default: {}, null: false
    t.text "critique_text"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "drill_instances", id: :string, force: :cascade do |t|
    t.string "topic_id", null: false
    t.string "graph_version_id", null: false
    t.string "source_version_id", null: false
    t.string "rubric_version_id", null: false
    t.string "diagnostic", null: false
    t.integer "seed", null: false
    t.jsonb "prompt_payload_json", default: {}, null: false
    t.jsonb "answer_key_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id", "graph_version_id", "rubric_version_id", "diagnostic", "seed"], name: "idx_drill_instances_unique_seed", unique: true
  end

  create_table "edge_audits", id: :string, force: :cascade do |t|
    t.string "edge_id", null: false
    t.string "drill_instance_id", null: false
    t.boolean "passed_bool", default: false, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "edge_evidence", id: :string, force: :cascade do |t|
    t.string "edge_id", null: false
    t.string "source_span_id", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "edge_mastery", id: :string, force: :cascade do |t|
    t.string "edge_id", null: false
    t.float "mastery_float", default: 0.0, null: false
    t.datetime "last_seen_at"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edge_id"], name: "index_edge_mastery_on_edge_id", unique: true
  end

  create_table "edges", id: :string, force: :cascade do |t|
    t.string "graph_version_id", null: false
    t.string "edge_id", null: false
    t.string "from_node_id", null: false
    t.string "to_node_id", null: false
    t.string "edge_type", null: false
    t.jsonb "mechanism_json", default: {}, null: false
    t.boolean "is_anchor", default: false, null: false
    t.integer "audit_passed_count_int", default: 0, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["graph_version_id", "edge_id"], name: "index_edges_on_graph_version_id_and_edge_id", unique: true
    t.index ["graph_version_id", "is_anchor"], name: "idx_edges_graph_anchor"
  end

  create_table "graph_versions", id: :string, force: :cascade do |t|
    t.string "topic_id", null: false
    t.integer "version_int", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id", "version_int"], name: "index_graph_versions_on_topic_id_and_version_int", unique: true
  end

  create_table "nodes", id: :string, force: :cascade do |t|
    t.string "graph_version_id", null: false
    t.string "node_id", null: false
    t.string "label", null: false
    t.string "definition_1s", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["graph_version_id", "node_id"], name: "index_nodes_on_graph_version_id_and_node_id", unique: true
  end

  create_table "rubric_versions", id: :string, force: :cascade do |t|
    t.string "version", null: false
    t.jsonb "config_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["version"], name: "index_rubric_versions_on_version", unique: true
  end

  create_table "schedules", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.jsonb "state_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "updated_at", null: false
    t.datetime "created_at", null: false
    t.index ["user_id"], name: "index_schedules_on_user_id", unique: true
  end

  create_table "scores", id: :string, force: :cascade do |t|
    t.string "attempt_id", null: false
    t.integer "points_total", default: 0, null: false
    t.jsonb "points_by_dimension_json", default: {}, null: false
    t.jsonb "evidence_refs_json", default: [], null: false
    t.string "result_code", default: "scored", null: false
    t.text "critique_text"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attempt_id"], name: "index_scores_on_attempt_id", unique: true
  end

  create_table "scout_artifacts", id: :string, force: :cascade do |t|
    t.string "session_pack_id", null: false
    t.string "workflow_run_id"
    t.string "user_id", null: false
    t.jsonb "output_json", default: {}, null: false
    t.string "payload_hash", null: false
    t.jsonb "policy_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_pack_id"], name: "index_scout_artifacts_on_session_pack_id"
    t.index ["workflow_run_id"], name: "index_scout_artifacts_on_workflow_run_id"
  end

  create_table "session_packs", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "topic_id", null: false
    t.string "graph_version_id", null: false
    t.string "source_version_id", null: false
    t.string "rubric_version_id", null: false
    t.jsonb "drill_instance_ids", default: [], null: false
    t.datetime "score_frozen_at"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "share_pack_artifacts", id: :string, force: :cascade do |t|
    t.string "workflow_run_id", null: false
    t.string "user_id", null: false
    t.string "topic_id", null: false
    t.string "format", null: false
    t.string "image_path"
    t.string "markdown_path"
    t.jsonb "payload_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "source_spans", id: :string, force: :cascade do |t|
    t.string "source_version_id", null: false
    t.string "span_id", null: false
    t.integer "ordinal", null: false
    t.integer "start_char", null: false
    t.integer "end_char", null: false
    t.string "heading"
    t.text "text", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_version_id", "span_id"], name: "index_source_spans_on_source_version_id_and_span_id", unique: true
  end

  create_table "source_versions", id: :string, force: :cascade do |t|
    t.string "source_id", null: false
    t.string "content_hash", null: false
    t.text "extracted_text", null: false
    t.text "extracted_html"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id", "content_hash"], name: "idx_source_versions_source_hash", unique: true
  end

  create_table "sources", id: :string, force: :cascade do |t|
    t.string "url", null: false
    t.string "canonical_url"
    t.string "title"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tool_call_logs", id: :string, force: :cascade do |t|
    t.string "workflow_run_id"
    t.string "step_event_id"
    t.string "tool_name", null: false
    t.jsonb "input_json", default: {}, null: false
    t.jsonb "output_json", default: {}, null: false
    t.jsonb "policy_json", default: {}, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "topic_scores", id: :string, force: :cascade do |t|
    t.string "topic_id", null: false
    t.float "ous_raw_float", default: 0.0, null: false
    t.float "ous_display_float", default: 0.0, null: false
    t.integer "spaced_count_int", default: 0, null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "updated_at", null: false
    t.datetime "created_at", null: false
    t.index ["topic_id"], name: "index_topic_scores_on_topic_id", unique: true
  end

  create_table "topics", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "source_id"
    t.string "title", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "source_id", "title"], name: "idx_topics_user_source_title", unique: true
  end

  create_table "workflow_runs", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "workflow_type", null: false
    t.string "status", null: false
    t.string "idempotency_key", null: false
    t.jsonb "input_json", default: {}, null: false
    t.jsonb "bound_versions_json", default: {}, null: false
    t.jsonb "agent_run_state_json", default: {}, null: false
    t.jsonb "error_json"
    t.datetime "cancel_requested_at"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "workflow_type", "idempotency_key"], name: "idx_workflow_runs_idem", unique: true
  end

  create_table "workflow_step_events", id: :string, force: :cascade do |t|
    t.string "workflow_run_id", null: false
    t.string "step_name", null: false
    t.string "step_status", null: false
    t.string "tool_name"
    t.jsonb "input_json", default: {}, null: false
    t.jsonb "output_json", default: {}, null: false
    t.jsonb "bound_versions_json", default: {}, null: false
    t.string "input_hash", null: false
    t.string "output_hash", null: false
    t.string "tool_schema_version", null: false
    t.string "step_idempotency_key"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workflow_run_id", "step_name", "step_idempotency_key"], name: "idx_workflow_step_idem", unique: true, where: "(step_idempotency_key IS NOT NULL)"
  end

  create_table "xp_events", id: :string, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "topic_id", null: false
    t.string "edge_id"
    t.string "workflow_run_id", null: false
    t.integer "base", null: false
    t.float "correctness", null: false
    t.float "novelty", null: false
    t.float "spacing", null: false
    t.integer "xp", null: false
    t.string "schema_version", default: "1.0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
