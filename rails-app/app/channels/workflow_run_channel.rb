# frozen_string_literal: true

class WorkflowRunChannel < ApplicationCable::Channel
  def subscribed
    stream_from "workflow_runs:#{params[:id]}"
  end
end
