# frozen_string_literal: true

class AddIteration7Constraints < ActiveRecord::Migration[8.0]
  def change
    add_index :attempts, [:user_id, :drill_instance_id], unique: true, name: "idx_attempts_user_drill_unique"
    add_index :edges, [:graph_version_id, :is_anchor], name: "idx_edges_graph_anchor"
  end
end
