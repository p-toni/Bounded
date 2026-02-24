# frozen_string_literal: true

require_relative "spec_helper"

class TypesSpec < Minitest::Test
  def test_base_type_validation
    type = GeometryGym::Types::Base.new("id" => "abc", "schema_version" => "1.0.0")
    assert_equal "abc", type.fetch(:id)
    assert type.validate_required!(:id, :schema_version)
  end
end
