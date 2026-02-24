# frozen_string_literal: true

Rails.application.routes.draw do
  resources :workflow_runs, only: [:create, :show] do
    member do
      post :cancel
      post :continue
      get :events
      get :replay
      get :inspector
    end
  end

  resources :session_packs, only: [] do
    resources :attempts, only: [:create], controller: "session_attempts"
    resource :scout, only: [:create], controller: "scout"
  end

  resources :sources, only: [:show] do
    collection do
      post :ingest
    end
  end

  resources :topics, only: [] do
    resource :score, only: [:show], controller: "topic_scores"
    resources :curvature_signals, only: [:index]
  end

  resources :approval_tokens, only: [:create]
  post "/exports/bundle", to: "exports#bundle"
  post "/deletions", to: "deletions#create"

  post "/tools/:name/call", to: "tools#call"

  mount ActionCable.server => "/cable"
end
