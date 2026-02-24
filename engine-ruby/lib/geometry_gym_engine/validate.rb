# frozen_string_literal: true

require "json"

module GeometryGymEngine
  module Validate
    module_function

    def schema_dir
      ENV.fetch("GEOMETRY_GYM_SCHEMA_DIR") do
        File.expand_path("../../../schemas/v1", __dir__)
      end
    end

    def validate!(schema_name, payload)
      schema = load_schema(schema_name)
      required = Array(schema["required"])
      missing = required.reject { |k| payload.key?(k) }
      raise ArgumentError, "Missing required keys for #{schema_name}: #{missing.join(', ')}" unless missing.empty?

      payload
    end

    def load_schema(schema_name)
      path = File.join(schema_dir, "#{schema_name}.json")
      JSON.parse(File.read(path))
    end
  end
end
