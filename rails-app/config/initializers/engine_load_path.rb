# frozen_string_literal: true

engine_lib = Rails.root.join("..", "engine-ruby", "lib").to_s
$LOAD_PATH.unshift(engine_lib) unless $LOAD_PATH.include?(engine_lib)
