# frozen_string_literal: true

class TopicScoresController < ApplicationController
  def show
    topic = Topic.find(params[:topic_id])
    score = TopicScore.find_or_initialize_by(topic_id: topic.id)

    if score.new_record?
      score = Workflows::TopicScoreUpdater.call(user_id: current_user_id, topic_id: topic.id)
    end

    render json: score.as_json
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
