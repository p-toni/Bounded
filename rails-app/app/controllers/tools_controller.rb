# frozen_string_literal: true

class ToolsController < ApplicationController
  def call
    result = Tools::Registry.call(
      name: params[:name],
      input_json: params.fetch(:input_json, {}).to_unsafe_h,
      context: { user_id: current_user_id, workflow_type: params[:workflow_type], workflow_run_id: params[:workflow_run_id], step_event_id: params[:step_event_id] }
    )

    render json: result
  rescue Tools::Registry::UnknownTool => e
    render json: { error: e.message }, status: :not_found
  rescue Tools::Registry::PermissionDenied => e
    render json: { error: e.message }, status: :forbidden
  end
end
