# frozen_string_literal: true

class ApprovalTokensController < ApplicationController
  def create
    issued = Security::ApprovalTokens.issue(
      user_id: current_user_id,
      action: token_params.fetch(:action),
      scope: token_params.fetch(:scope),
      resource_id: token_params[:resource_id],
      ttl_minutes: token_params[:ttl_minutes]
    )

    render json: issued, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def token_params
    params.permit(:action, :scope, :resource_id, :ttl_minutes)
  end
end
