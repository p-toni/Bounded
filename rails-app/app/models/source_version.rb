# frozen_string_literal: true

class SourceVersion < ApplicationRecord
  belongs_to :source
  has_many :source_spans, dependent: :destroy

  validates :content_hash, :extracted_text, presence: true
end
