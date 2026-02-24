# frozen_string_literal: true

class ExportsController < ApplicationController
  def bundle
    scope = export_params.fetch(:scope)
    Security::ApprovalTokens.consume!(
      user_id: current_user_id,
      action: "export",
      scope: scope,
      approval_token: export_params.fetch(:approval_token)
    )

    result = Workflows::ExportBundle.call(user_id: current_user_id, scope: scope)
    render json: result, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def export_params
    params.permit(:scope, :approval_token)
  end
end
