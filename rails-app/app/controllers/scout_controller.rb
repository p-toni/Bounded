# frozen_string_literal: true

class ScoutController < ApplicationController
  def create
    result = Workflows::ScoutPostFreeze.call(
      user_id: current_user_id,
      session_pack_id: params.fetch(:session_pack_id),
      workflow_run_id: params[:workflow_run_id]
    )

    render json: result, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
