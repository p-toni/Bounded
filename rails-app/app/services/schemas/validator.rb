# frozen_string_literal: true

require "json"
require "time"
require "uri"
require "bigdecimal"

module Schemas
  class Validator
    def self.call!(schema_name:, payload:)
      schema = load_schema(schema_name)
      normalized_payload = normalize_payload(schema: schema, root_schema: schema, payload: payload)
      errors = validate(schema: schema, root_schema: schema, payload: normalized_payload, path: "$")
      unless errors.empty?
        raise ArgumentError, "Schema validation failed for #{schema_name}: #{errors.join('; ')}"
      end

      normalized_payload
    end

    def self.load_schema(schema_name)
      schema_path = Rails.root.join("..", "schemas", "v1", "#{schema_name}.json")
      JSON.parse(File.read(schema_path))
    end

    def self.validate(schema:, root_schema:, payload:, path:)
      node = resolve_ref(schema: schema, root_schema: root_schema)
      return [] unless node.is_a?(Hash)

      errors = []

      if node.key?("type")
        allowed_types = Array(node.fetch("type")).map(&:to_s)
        unless allowed_types.any? { |t| type_match?(payload, t) }
          return ["#{path}: expected type #{allowed_types.join(' or ')}, got #{json_type(payload)}"]
        end
      end

      if node.key?("const") && payload != node.fetch("const")
        errors << "#{path}: expected const #{node.fetch('const').inspect}"
      end

      if node.key?("enum")
        allowed_values = Array(node.fetch("enum"))
        errors << "#{path}: expected one of #{allowed_values.inspect}" unless allowed_values.include?(payload)
      end

      if payload.is_a?(Numeric)
        if node.key?("minimum") && payload < node.fetch("minimum").to_f
          errors << "#{path}: must be >= #{node.fetch('minimum')}"
        end
        if node.key?("maximum") && payload > node.fetch("maximum").to_f
          errors << "#{path}: must be <= #{node.fetch('maximum')}"
        end
      end

      if payload.is_a?(String) && node.key?("format")
        format = node.fetch("format")
        errors << "#{path}: invalid #{format} format" unless valid_format?(payload, format)
      end

      if payload.is_a?(Array)
        if node.key?("minItems") && payload.length < node.fetch("minItems").to_i
          errors << "#{path}: must contain at least #{node.fetch('minItems')} items"
        end
        if node.key?("maxItems") && payload.length > node.fetch("maxItems").to_i
          errors << "#{path}: must contain at most #{node.fetch('maxItems')} items"
        end

        item_schema = node["items"]
        if item_schema
          payload.each_with_index do |item, idx|
            errors.concat(validate(schema: item_schema, root_schema: root_schema, payload: item, path: "#{path}[#{idx}]"))
          end
        end
      end

      if payload.is_a?(Hash)
        properties = node.fetch("properties", {})
        required = Array(node.fetch("required", []))

        required.each do |key|
          errors << "#{path}.#{key}: missing required key" unless payload.key?(key.to_s)
        end

        payload.each do |key, value|
          next unless properties.key?(key)

          errors.concat(validate(schema: properties.fetch(key), root_schema: root_schema, payload: value, path: "#{path}.#{key}"))
        end

        additional = node.fetch("additionalProperties", true)
        unknown_keys = payload.keys - properties.keys
        if additional == false
          unknown_keys.each { |key| errors << "#{path}.#{key}: additional property is not allowed" }
        elsif additional.is_a?(Hash)
          unknown_keys.each do |key|
            errors.concat(validate(schema: additional, root_schema: root_schema, payload: payload.fetch(key), path: "#{path}.#{key}"))
          end
        end
      end

      Array(node["allOf"]).each_with_index do |subschema, idx|
        errors.concat(validate(schema: subschema, root_schema: root_schema, payload: payload, path: "#{path}.allOf[#{idx}]"))
      end

      if node["if"]
        if_match = validate(schema: node.fetch("if"), root_schema: root_schema, payload: payload, path: "#{path}.if").empty?
        if if_match && node["then"]
          errors.concat(validate(schema: node.fetch("then"), root_schema: root_schema, payload: payload, path: "#{path}.then"))
        elsif !if_match && node["else"]
          errors.concat(validate(schema: node.fetch("else"), root_schema: root_schema, payload: payload, path: "#{path}.else"))
        end
      end

      errors
    end

    def self.normalize_payload(schema:, root_schema:, payload:)
      node = resolve_ref(schema: schema, root_schema: root_schema)
      return deep_stringify(payload) unless node.is_a?(Hash)

      normalized = payload
      if normalized.is_a?(Hash)
        normalized = deep_stringify(normalized)
        properties = node.fetch("properties", {})
        if node.fetch("additionalProperties", true) == false && !properties.key?("updated_at")
          normalized = normalized.reject { |key, _| key == "updated_at" }
        end

        normalized.each_with_object({}) do |(key, value), memo|
          property_schema = properties[key]
          memo[key] = if property_schema
                        normalize_payload(schema: property_schema, root_schema: root_schema, payload: value)
                      else
                        value
                      end
        end
      elsif normalized.is_a?(Array)
        item_schema = node["items"]
        return normalized unless item_schema

        normalized.map do |item|
          normalize_payload(schema: item_schema, root_schema: root_schema, payload: item)
        end
      else
        normalize_scalar(node: node, value: normalized)
      end
    end

    def self.deep_stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), memo|
          memo[key.to_s] = deep_stringify(item)
        end
      when Array
        value.map { |item| deep_stringify(item) }
      else
        value
      end
    end

    def self.resolve_ref(schema:, root_schema:)
      return schema unless schema.is_a?(Hash) && schema["$ref"].is_a?(String)

      ref = schema.fetch("$ref")
      return schema unless ref.start_with?("#/")

      path_parts = ref.sub("#/", "").split("/")
      resolved = path_parts.reduce(root_schema) do |memo, part|
        memo.fetch(part)
      end

      return resolved if schema.keys == ["$ref"]

      resolved.merge(schema.reject { |key, _| key == "$ref" })
    end

    def self.type_match?(value, expected_type)
      case expected_type
      when "object" then value.is_a?(Hash)
      when "array" then value.is_a?(Array)
      when "string" then value.is_a?(String)
      when "integer" then value.is_a?(Integer)
      when "number" then value.is_a?(Numeric)
      when "boolean" then value == true || value == false
      when "null" then value.nil?
      else
        false
      end
    end

    def self.valid_format?(value, format)
      case format
      when "date-time"
        Time.iso8601(value)
        true
      when "uri"
        uri = URI.parse(value)
        uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      else
        true
      end
    rescue ArgumentError, URI::InvalidURIError
      false
    end

    def self.json_type(value)
      case value
      when Hash then "object"
      when Array then "array"
      when String then "string"
      when Integer then "integer"
      when Numeric then "number"
      when true, false then "boolean"
      when nil then "null"
      else
        value.class.name
      end
    end

    def self.normalize_scalar(node:, value:)
      return value if value.nil?

      allowed_types = Array(node["type"]).map(&:to_s)
      if allowed_types.include?("string")
        if node["format"] == "date-time" && value.respond_to?(:iso8601)
          begin
            return value.to_time.utc.iso8601
          rescue NoMethodError
            return value.iso8601
          end
        end

        return value.to_s if value.is_a?(Symbol)
      end

      if allowed_types.include?("integer") && value.is_a?(BigDecimal)
        return value.to_i if value.frac.zero?
      end

      if allowed_types.include?("number") && value.is_a?(BigDecimal)
        return value.to_f
      end

      value
    end
  end
end
