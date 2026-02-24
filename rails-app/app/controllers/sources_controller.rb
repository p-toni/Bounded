# frozen_string_literal: true

class SourcesController < ApplicationController
  def ingest
    result = Workflows::SourceIngest.call(
      user_id: current_user_id,
      url: ingest_params.fetch(:url),
      topic_title: ingest_params[:topic_title]
    )

    render json: result, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  def show
    source = Source.find(params[:id])
    latest_version = source.source_versions.order(created_at: :desc).first

    render json: {
      source: source.as_json,
      latest_source_version: latest_version&.as_json,
      spans_preview: latest_version ? latest_version.source_spans.order(:ordinal).limit(5).map(&:as_json) : []
    }
  end

  private

  def ingest_params
    params.permit(:url, :topic_title)
  end
end
