# frozen_string_literal: true

module Protocol
  class Streamer
    def self.publish!(run:, event:)
      ActionCable.server.broadcast("workflow_runs:#{run.id}", event)
    end
  end
end
