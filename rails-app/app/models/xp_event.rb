# frozen_string_literal: true

class XpEvent < ApplicationRecord
  belongs_to :workflow_run, optional: true
end
