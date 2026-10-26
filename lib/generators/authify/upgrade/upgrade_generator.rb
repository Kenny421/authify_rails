# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "authify/installation_manifest"

module Authify
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def check_installation
        raise Thor::Error, "Authify is not installed." unless manifest.installed?
      end

      def report
        say "Authify application version: #{installed_version || 'unknown'}"
        say "Authify gem version: #{Authify::VERSION}"
        say "Installed features: #{manifest.features.sort.join(', ')}"
        say ""
        say "This release has no automatic destructive upgrades.", :green
        say "Review UPGRADING.md and run bin/rails authify:doctor after updating."
      end

      def create_compatibility_migration
        return unless manifest.feature?(:core)

        # Re-running an upgrade must never overwrite a migration an application
        # has already reviewed or applied to production.
        existing = Dir.glob(File.join(destination_root, "db/migrate/*_upgrade_authify_security_fields.rb"))
        if existing.any?
          say "Authify security migration already exists; leaving it unchanged.", :green
          return
        end

        migration_template "compatibility_migration.rb.tt", "db/migrate/upgrade_authify_security_fields.rb"
      end

      private

      def manifest
        @manifest ||= Authify::InstallationManifest.new(root: destination_root)
      end

      def installed_version
        YAML.safe_load_file(manifest.path, permitted_classes: [], aliases: false)&.fetch("version", nil)
      rescue Psych::SyntaxError
        nil
      end

      def user_table
        (YAML.safe_load_file(manifest.path, permitted_classes: [], aliases: false)&.fetch("user_model", "User") || "User")
          .underscore.pluralize
      rescue Psych::SyntaxError
        "users"
      end
    end
  end
end
