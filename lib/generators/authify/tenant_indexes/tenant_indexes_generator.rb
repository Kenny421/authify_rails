require "rails/generators"
require "rails/generators/active_record"
require "authify/installation_manifest"
module Authify
  module Generators
    class TenantIndexesGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)
      def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
      def generate_migration
        manifest = Authify::InstallationManifest.new(root: destination_root)
        raise Thor::Error, "Install --multi-tenant first" unless manifest.feature?(:multi_tenant)
        @user_table = manifest.user_model.underscore.pluralize
        migration_template "migration.rb.tt", "db/migrate/scope_authify_email_indexes_to_tenants.rb"
        say "Review the migration: it REPLACES global email constraints. Backfill every user's tenant_id, back up, then run db:migrate. It never runs automatically."
      end
      private
      def user_table = @user_table
    end
  end
end
