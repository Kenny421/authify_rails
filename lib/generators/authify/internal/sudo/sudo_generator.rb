require "authify/generator_views"
# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Authify
  module Generators
    module Internal
      class SudoGenerator < Rails::Generators::Base
    include Authify::GeneratorViews
        include Rails::Generators::Migration
        source_root File.expand_path("templates", __dir__)
        class_option :views, type: :string, default: "tailwind"

        def self.next_migration_number(dirname)
          ActiveRecord::Generators::Base.next_migration_number(dirname)
        end

        def generate_files
          migration_template "migration.rb.tt", "db/migrate/add_sudo_to_authify_sessions.rb"
          template "concern.rb.tt", "app/controllers/concerns/authify/sudo.rb"
          template "controller.rb.tt", "app/controllers/authify/sudo_controller.rb"
          template "compatibility_controller.rb.tt", "app/controllers/authify/sudos_controller.rb"
          template "view.html.erb.tt", "app/views/authify/sudo/new.html.erb" unless options[:views] == "none"
          plain_view!("app/views/authify/sudo/new.html.erb")
          inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "  include Authify::Sudo\n"
          route 'scope module: :authify do; resource :sudo, controller: "sudo", only: %i[new create destroy]; end'
        end
      end
    end
  end
end
