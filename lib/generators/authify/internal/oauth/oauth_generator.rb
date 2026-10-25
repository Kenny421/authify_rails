# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Authify
  module Generators
    module Internal
      class OauthGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        source_root File.expand_path("templates", __dir__)

        class_option :user_model, type: :string, default: "User"
        class_option :views, type: :string, default: "tailwind"

        def self.next_migration_number(dirname)
          ActiveRecord::Generators::Base.next_migration_number(dirname)
        end

        def create_identity_model
          template "model.rb.tt", "app/models/authify_oauth_identity.rb"
          inject_into_class user_model_path, user_model,
                            "  has_many :authify_oauth_identities, dependent: :destroy\n"
        end

        def create_oauth_migration
          migration_template "migration.rb.tt", "db/migrate/create_authify_oauth_identities.rb"
        end

        def create_controller
          template "controller.rb.tt", "app/controllers/authify/oauth_callbacks_controller.rb"
        end

        def create_initializer
          template "initializer.rb.tt", "config/initializers/authify_oauth.rb"
        end

        def add_routes
          route <<~RUBY
            scope module: :authify do
              match "/auth/:provider/callback", to: "oauth_callbacks#create", via: %i[get post], as: :authify_oauth_callback
              match "/auth/failure", to: "oauth_callbacks#failure", via: %i[get post], as: :authify_oauth_failure
            end
          RUBY
        end

        def add_oauth_buttons
          return if options[:views] == "none"

          template "buttons.html.erb.tt", "app/views/authify/shared/_oauth_buttons.html.erb"
          %w[sessions/new registrations/new].each do |view|
            path = "app/views/authify/#{view}.html.erb"
            append_to_file path, "\n<%= render \"authify/shared/oauth_buttons\" %>\n" if File.exist?(File.join(destination_root, path))
          end
        end

        def create_oauth_security_tests
          template "test.rb.tt", "test/integration/authify_oauth_security_test.rb"
        end

        private

        def user_model
          options[:user_model]
        end

        def user_model_path
          "app/models/#{user_model.underscore}.rb"
        end
      end
    end
  end
end
