# frozen_string_literal: true

require "rails"
require "active_support"
require "active_support/core_ext/numeric/time"
require_relative "authify/version"
require_relative "authify/configuration"
require_relative "authify/engine"
require_relative "authify/token"
require_relative "authify/password_breach_checker"
require_relative "authify/installation_manifest"
require_relative "authify/tenant"

module Authify
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
