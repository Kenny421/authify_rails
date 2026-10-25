# frozen_string_literal: true

# Bundler requires a gem's name by default. Keep this conventional entrypoint
# so `gem "authify_rails"` loads the public Authify API before Rails initializers.
require_relative "authify"
