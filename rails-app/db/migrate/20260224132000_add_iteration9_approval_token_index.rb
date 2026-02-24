# frozen_string_literal: true

class AddIteration9ApprovalTokenIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :approval_tokens, [:user_id, :action, :scope, :token_hash], name: "idx_approval_tokens_lookup"
  end
end
