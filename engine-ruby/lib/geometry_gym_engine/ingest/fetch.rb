# frozen_string_literal: true

require "net/http"
require "uri"

module GeometryGymEngine
  module Ingest
    module Fetch
      module_function

      def call(url)
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        {
          canonical_url: response.uri.to_s,
          raw_html: response.body.to_s
        }
      end
    end
  end
end
