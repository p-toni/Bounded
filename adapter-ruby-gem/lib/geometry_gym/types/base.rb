# frozen_string_literal: true

require "json"

module GeometryGym
  module Types
    class Base
      attr_reader :attributes

      def initialize(attributes)
        @attributes = attributes.transform_keys(&:to_s)
      end

      def fetch(key)
        attributes.fetch(key.to_s)
      end

      def to_h
        attributes.dup
      end

      def validate_required!(*keys)
        missing = keys.flatten.map(&:to_s).reject { |k| attributes.key?(k) }
        raise ArgumentError, "Missing keys: #{missing.join(', ')}" unless missing.empty?

        self
      end

      def to_json(*args)
        attributes.to_json(*args)
      end
    end
  end
end
