# frozen_string_literal: true

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module GeometryGymApp
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = false
    config.time_zone = "UTC"
    config.active_job.queue_adapter = :sidekiq
  end
end
