# frozen_string_literal: true

class AddIteration8IngestIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :source_versions, [:source_id, :content_hash], unique: true, name: "idx_source_versions_source_hash"
    add_index :topics, [:user_id, :source_id, :title], unique: true, name: "idx_topics_user_source_title"
  end
end
