# frozen_string_literal: true

require "fileutils"
require "yaml"

module Authify
  class InstallationManifest
    DEFAULT_PATH = "config/authify.yml"

    attr_reader :path

    def initialize(root:, path: DEFAULT_PATH)
      @root = root
      @path = File.join(root, path)
      @data = load_data
    end

    def installed?
      File.exist?(path) || File.exist?(File.join(@root, "config/initializers/authify.rb")) || @data.fetch("features", {}).fetch("core", false)
    end

    def feature?(name)
      @data.fetch("features", {}).fetch(name.to_s, false)
    end

    def record!(version:, user_model:, views:, features:)
      @data["version"] = version
      @data["user_model"] = user_model
      @data["views"] = views
      @data["features"] ||= {}
      features.each { |feature| @data["features"][feature.to_s] = true }
      write!
    end

    def features
      @data.fetch("features", {}).select { |_name, enabled| enabled }.keys.map(&:to_sym)
    end

    private

    def load_data
      return {} unless File.exist?(path)

      YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
    rescue Psych::SyntaxError
      {}
    end

    def write!
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(@data))
    end
  end
end
