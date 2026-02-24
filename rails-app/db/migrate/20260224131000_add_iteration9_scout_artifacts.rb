# frozen_string_literal: true

class AddIteration9ScoutArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :scout_artifacts, id: :string do |t|
      t.string :session_pack_id, null: false
      t.string :workflow_run_id
      t.string :user_id, null: false
      t.jsonb :output_json, null: false, default: {}
      t.string :payload_hash, null: false
      t.jsonb :policy_json, null: false, default: {}
      t.string :schema_version, null: false, default: "1.0.0"
      t.timestamps
    end

    add_index :scout_artifacts, :session_pack_id
    add_index :scout_artifacts, :workflow_run_id
  end
end
