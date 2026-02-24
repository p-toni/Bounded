# frozen_string_literal: true

module Workflows
  class RenderSharePack
    def self.call(input)
      {
        format: "markdown",
        markdown: "# Geometry Gym Share Pack\n\nTopic: #{input['topic_id']}\nScore summary included.",
        image_path: nil
      }
    end
  end
end
