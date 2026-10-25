require "rails/generators"
require "rails/generators/active_record"
module Authify; module Generators; module Internal
  class RolesGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    class_option :user_model, type: :string, default: "User"
    def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
    def generate_files
      migration_template "migration.rb.tt", "db/migrate/create_authify_roles.rb"
      template "role.rb.tt", "app/models/authify_role.rb"
      template "assignment.rb.tt", "app/models/authify_role_assignment.rb"
      inject_into_class "app/models/#{options[:user_model].underscore}.rb", options[:user_model], "  has_many :authify_role_assignments, foreign_key: :user_id, dependent: :destroy\n  has_many :authify_roles, through: :authify_role_assignments\n\n  def has_role?(name)\n    authify_roles.exists?(name: name.to_s)\n  end\n"
    end
  end
end; end; end
