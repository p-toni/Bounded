# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  private

  # V1 default: single-user placeholder for bootstrap.
  def current_user_id
    request.headers["X-User-Id"].presence || "user_v1"
  end
end
