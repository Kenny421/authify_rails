# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "yaml"

module Authify
  class InstallationManifest
    DEFAULT_PATH = "config/authify.yml"

    # An unreadable manifest must never be mistaken for a fresh installation:
    # the installer could otherwise regenerate already-customized components.
    class InvalidManifest < StandardError; end

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

      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      return {} if data.nil?
      unless data.is_a?(Hash) && (data["features"].nil? || data["features"].is_a?(Hash))
        raise InvalidManifest, "Authify installation manifest at #{path} must be a mapping with a features mapping."
      end

      data
    rescue Psych::Exception => e
      raise InvalidManifest, "Cannot safely read Authify installation manifest at #{path}: #{e.class}"
    end

    def write!
      FileUtils.mkdir_p(File.dirname(path))
      # Write and rename in the same directory so interrupted upgrades cannot
      # leave a partially written manifest behind.
      Tempfile.create([".authify-manifest-", ".yml"], File.dirname(path)) do |temp|
        temp.write(YAML.dump(@data))
        temp.flush
        temp.fsync
        File.rename(temp.path, path)
      end
    end
  end
end
