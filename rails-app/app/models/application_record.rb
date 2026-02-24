# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_create :assign_string_id

  private

  def assign_string_id
    self.id ||= SecureRandom.uuid
  end
end
