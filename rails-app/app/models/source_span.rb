# frozen_string_literal: true

class SourceSpan < ApplicationRecord
  belongs_to :source_version

  validates :span_id, :text, :ordinal, presence: true
end
