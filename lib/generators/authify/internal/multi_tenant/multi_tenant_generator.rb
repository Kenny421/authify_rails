require "rails/generators"
require "rails/generators/active_record"
module Authify
  module Generators
    module Internal
      class MultiTenantGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        source_root File.expand_path("templates", __dir__)
        class_option :user_model, type: :string, default: "User"
        def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
        def generate_files
          template "initializer.rb.tt", "config/initializers/authify_tenant.rb"
          migration_template "migration.rb.tt", "db/migrate/prepare_authify_tenant_authentication.rb"
          say "Configure a trusted tenant resolver, backfill users, review tenant indexes, then explicitly enable tenant authentication.", :yellow
        end
      end
    end
  end
end
