# frozen_string_literal: true

module GeometryGymEngine
  module Parse
    module Extract
      module_function

      def call(raw_html)
        html = raw_html.to_s.dup
        title = html[/<title>(.*?)<\/title>/im, 1]&.strip
        html.gsub!(%r{<script.*?</script>}im, "")
        html.gsub!(%r{<style.*?</style>}im, "")
        html.gsub!(%r{<[^>]+>}, " ")
        html.gsub!(/\s+/, " ")

        {
          extracted_text: html.strip,
          title: title
        }
      end
    end
  end
end
