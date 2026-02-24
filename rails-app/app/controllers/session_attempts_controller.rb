# frozen_string_literal: true

class SessionAttemptsController < ApplicationController
  def create
    attrs = attempt_params
    answer_payload = attrs[:answer_json]
    answer_payload = answer_payload.to_unsafe_h if answer_payload.is_a?(ActionController::Parameters)

    result = Workflows::SessionRepSubmit.call(
      user_id: current_user_id,
      session_pack_id: params.fetch(:session_pack_id),
      drill_instance_id: attrs.fetch(:drill_instance_id),
      answer_json: answer_payload || {},
      duration_ms: attrs.fetch(:duration_ms, 0),
      source_opened_bool: attrs.fetch(:source_opened_bool, false),
      workflow_run_id: attrs[:workflow_run_id]
    )

    render json: result, status: :created
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def attempt_params
    permitted = params.require(:attempt).permit(
      :drill_instance_id,
      :duration_ms,
      :source_opened_bool,
      :workflow_run_id
    )

    raw_answer = params.require(:attempt)[:answer_json]
    if raw_answer.is_a?(ActionController::Parameters)
      permitted[:answer_json] = raw_answer.to_unsafe_h
    elsif raw_answer.is_a?(Hash)
      permitted[:answer_json] = raw_answer
    end

    permitted
  end
end
