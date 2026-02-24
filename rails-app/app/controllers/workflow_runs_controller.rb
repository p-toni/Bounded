# frozen_string_literal: true

class WorkflowRunsController < ApplicationController
  def create
    run = WorkflowRun.find_by(
      user_id: current_user_id,
      workflow_type: params.require(:workflow_type),
      idempotency_key: params.require(:idempotency_key)
    )

    run ||= WorkflowRun.create!(
      user_id: current_user_id,
      workflow_type: params.require(:workflow_type),
      status: "queued",
      idempotency_key: params.require(:idempotency_key),
      input_json: params.fetch(:input, {}).to_unsafe_h,
      bound_versions_json: { "schema_version" => "1.0.0", "policy_version" => "v1" },
      agent_run_state_json: { "step_index" => 0 },
      schema_version: "1.0.0"
    )

    Schemas::Validator.call!(schema_name: "workflow_run", payload: run.attributes)
    dispatch_workflow_run!(run.id)
    render json: run.as_json, status: :accepted
  end

  def show
    run = scoped_run
    render json: run.as_json
  end

  def cancel
    run = scoped_run
    run.update!(cancel_requested_at: Time.current)
    render json: { id: run.id, status: run.status, cancel_requested_at: run.cancel_requested_at }
  end

  def continue
    run = scoped_run
    run.with_lock do
      state = (run.agent_run_state_json || {}).merge("input_delta" => params.fetch(:input_delta, {}).to_unsafe_h)
      run.update!(agent_run_state_json: state, status: "running")
    end
    dispatch_workflow_run!(run.id)
    render json: run.as_json
  end

  def events
    run = scoped_run
    events = run.workflow_step_events.order(:created_at)
    if params[:cursor].present?
      events = events.where("id > ?", params[:cursor])
    end

    render json: events.limit(200).map(&:as_json)
  end

  def replay
    run = scoped_run
    result = Workflows::EngineBridge.replay(
      workflow_run: run.attributes,
      step_events: run.workflow_step_events.order(:created_at).map(&:attributes)
    )
    render json: result
  end

  def inspector
    @workflow_run = scoped_run
    @filters = {
      step_name: params[:step_name].presence,
      step_status: params[:step_status].presence,
      tool_name: params[:tool_name].presence
    }

    base_step_events = @workflow_run.workflow_step_events.order(:created_at)
    @total_step_events_count = base_step_events.count
    @step_events = apply_step_filters(base_step_events, @filters)

    base_tool_logs = @workflow_run.tool_call_logs.order(:created_at)
    @total_tool_logs_count = base_tool_logs.count
    @tool_logs = apply_tool_filters(base_tool_logs, @filters, @step_events)

    render :inspector
  end

  private

  def scoped_run
    WorkflowRun.find_by!(id: params[:id], user_id: current_user_id)
  end

  def apply_step_filters(scope, filters)
    out = scope
    out = out.where(step_name: filters[:step_name]) if filters[:step_name].present?
    out = out.where(step_status: filters[:step_status]) if filters[:step_status].present?
    out
  end

  def apply_tool_filters(scope, filters, filtered_step_events)
    out = scope
    out = out.where(tool_name: filters[:tool_name]) if filters[:tool_name].present?
    if filters[:step_name].present? || filters[:step_status].present?
      out = out.where(step_event_id: filtered_step_events.select(:id))
    end
    out
  end

  # Local fallback: if Redis/Sidekiq is unavailable, execute inline so API smoke flows still run.
  def dispatch_workflow_run!(workflow_run_id)
    WorkflowRunJob.perform_later(workflow_run_id)
  rescue StandardError => e
    raise unless redis_unavailable_error?(e)

    WorkflowRunJob.perform_now(workflow_run_id)
  end

  def redis_unavailable_error?(error)
    error.is_a?(Errno::ECONNREFUSED) || error.class.name.include?("RedisClient::CannotConnectError")
  end
end
