# frozen_string_literal: true
require "rails/generators"
require "rails/generators/active_record"
require "authify/installation_manifest"
require "authify/template_catalog"
require "authify/upgrade_plan"

module Authify
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)
      class_option :dry_run, type: :boolean, default: false, desc: "Preview without writing any files"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def check_installation
        raise Thor::Error, "Authify is not installed." unless manifest.feature?(:core)
        # Filesystem-only: this works before the application can boot on the new schema.
        if manifest.version && Gem::Version.new(manifest.version) > Gem::Version.new(Authify::VERSION)
          raise Thor::Error, "Refusing a downgrade. Restore the matching gem version."
        end
      end

      def upgrade
        candidates = catalog.files
        baselines = manifest.baselines
        if manifest.version == "0.3.0"
          baselines = Authify::TemplateCatalog.new(user_model: manifest.user_model, views: manifest.views, features: manifest.features, legacy: true).files.merge(baselines)
        end
        plan = Authify::UpgradePlan.new(root: destination_root, candidates: candidates, baselines: baselines)
        plan.entries.each { |entry| say_status(entry.status, entry.path) }
        say_status :migration, "add missing security fields; never runs db:migrate"
        return if options[:dry_run] || options[:pretend]
        if plan.conflicts?
          plan.write_review!
          raise Thor::Error, "No application files changed. Review .authify/upgrade/*.proposed (including subdirectories), resolve conflicts, and rerun. Manifest was not advanced."
        end
        plan.apply!
        migration_path = Dir[File.join(destination_root, "db/migrate/*_upgrade_authify_040_security_fields.rb")].first
        migration_template "compatibility_migration.rb.tt", "db/migrate/upgrade_authify_040_security_fields.rb" unless migration_path
        manifest.record_upgrade!(files: candidates) unless manifest.version == Authify::VERSION && manifest.baselines == candidates
        say "Review git diff, run bin/rails db:migrate, bin/rails authify:doctor and your application tests before deployment."
      end

      private
      def manifest
        @manifest ||= Authify::InstallationManifest.new(root: destination_root)
      end
      def catalog
        Authify::TemplateCatalog.new(user_model: manifest.user_model, views: manifest.views, features: manifest.features)
      end
      def user_table = manifest.user_model.underscore.pluralize
    end
  end
end
