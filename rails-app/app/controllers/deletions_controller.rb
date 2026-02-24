# frozen_string_literal: true

class DeletionsController < ApplicationController
  def create
    scope = deletion_params.fetch(:scope)
    Security::ApprovalTokens.consume!(
      user_id: current_user_id,
      action: "delete",
      scope: scope,
      approval_token: deletion_params.fetch(:approval_token)
    )

    result = Workflows::DeleteScope.call(user_id: current_user_id, scope: scope)
    render json: result, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def deletion_params
    params.permit(:scope, :approval_token)
  end
end
