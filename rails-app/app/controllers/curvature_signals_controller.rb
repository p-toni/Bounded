# frozen_string_literal: true

class CurvatureSignalsController < ApplicationController
  def index
    topic = Topic.find(params[:topic_id])
    raise ActiveRecord::RecordNotFound, "Topic not found" unless topic.user_id == current_user_id

    limit = [[params.fetch(:limit, 50).to_i, 1].max, 200].min
    signals = CurvatureSignal.where(topic_id: topic.id).order(created_at: :desc).limit(limit)

    render json: {
      topic_id: topic.id,
      count: signals.length,
      signals: signals.map(&:as_json)
    }
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
