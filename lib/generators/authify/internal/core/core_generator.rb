# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Authify
  module Generators
    module Internal
      class CoreGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        source_root File.expand_path("templates", __dir__)

        class_option :user_model, type: :string, default: "User"
        class_option :views, type: :string, default: "tailwind"

        def self.next_migration_number(dirname)
          ActiveRecord::Generators::Base.next_migration_number(dirname)
        end

        def create_initializer
          template "authify.rb.tt", "config/initializers/authify.rb"
        end

        def create_or_update_user
          path = "app/models/#{user_model.underscore}.rb"
          if File.exist?(File.join(destination_root, path))
            inject_into_class path, user_model, "  include Authify::Authenticatable\n  include Authify::SecurePassword\n"
          else
            template "user.rb.tt", path
          end
        end

        def create_models
          %w[authify_session authentication_event].each do |name|
            template "models/#{name}.rb.tt", "app/models/#{name}.rb"
          end
          empty_directory "app/models/concerns/authify"
          %w[authenticatable secure_password].each do |name|
            template "concerns/#{name}.rb.tt", "app/models/concerns/authify/#{name}.rb"
          end
          template "current.rb.tt", "app/models/current.rb"
        end

        def create_migrations
          migration_template "migrations/create_authify_core.rb.tt", "db/migrate/create_authify_core.rb"
        end

        def create_controllers
          %w[application sessions two_factor_challenges registrations passwords password_changes email_verifications email_changes account_sessions].each do |name|
            template "controllers/#{name}_controller.rb.tt", "app/controllers/authify/#{name}_controller.rb"
          end
          template "authentication.rb.tt", "app/controllers/concerns/authify/authentication.rb"
          template "current_session.rb.tt", "app/controllers/concerns/authify/current_session.rb"
        end

        def create_home_page
          return if options[:views] == "none"
          controller = "app/controllers/home_controller.rb"
          view = "app/views/home/index.html.erb"

          template "controllers/home_controller.rb.tt", controller unless File.exist?(File.join(destination_root, controller))
          template "home_index.html.erb.tt", view unless File.exist?(File.join(destination_root, view))
        end

        def create_mailer
          template "mailer.rb.tt", "app/mailers/authify_mailer.rb"
          %w[email_verification email_change_verification email_change_requested email_changed password_reset welcome password_changed new_sign_in].each do |name|
            %w[html text].each do |format|
              template "mailer_views/#{name}.#{format}.erb.tt", "app/views/authify_mailer/#{name}.#{format}.erb"
            end
          end
          template "mailer_views/layout.html.erb.tt", "app/views/layouts/authify_mailer.html.erb"
          template "mailer_views/layout.text.erb.tt", "app/views/layouts/authify_mailer.text.erb"
          template "mailer_preview.rb.tt", "test/mailers/previews/authify_mailer_preview.rb"
        end

        def create_views
          return if options[:views] == "none"
          directory(options[:views] == "plain" ? "plain_views" : "views", "app/views/authify")
        end

        def add_routes
          route <<~RUBY
            scope module: :authify do
              get "/sign-in", to: "sessions#new", as: :new_session
              post "/sign-in", to: "sessions#create", as: :session
              delete "/sign-out", to: "sessions#destroy", as: :sign_out

              get "/sign-up", to: "registrations#new", as: :new_registration
              post "/sign-up", to: "registrations#create", as: :registration

              get "/two-factor", to: "two_factor_challenges#new", as: :new_two_factor_challenge
              post "/two-factor", to: "two_factor_challenges#create", as: :two_factor_challenge

              get "/forgot-password", to: "passwords#new", as: :new_password
              post "/forgot-password", to: "passwords#create", as: :passwords
              get "/reset-password/:token", to: "passwords#edit", as: :edit_password
              patch "/reset-password/:token", to: "passwords#update", as: :password

              get "/account/password", to: "password_changes#edit", as: :edit_account_password
              patch "/account/password", to: "password_changes#update", as: :account_password

              get "/verify-email", to: "email_verifications#new", as: :new_email_verification
              post "/verify-email", to: "email_verifications#create", as: :email_verifications
              get "/verify-email/:token", to: "email_verifications#show", as: :email_verification

              get "/account/email", to: "email_changes#edit", as: :edit_account_email
              patch "/account/email", to: "email_changes#update", as: :account_email
              delete "/account/email", to: "email_changes#destroy"
              get "/confirm-email-change/:token", to: "email_changes#show", as: :confirm_email_change

              resources :account_sessions, path: "account/sessions", only: %i[index destroy]
            end
          RUBY
        end

        def add_root_route
          return if options[:views] == "none"
          routes_path = File.join(destination_root, "config/routes.rb")
          routes = File.exist?(routes_path) ? File.read(routes_path) : ""
          return say_status(:identical, "existing root route") if routes.match?(/^\s*root(?:\s|\()/)

          route 'root "home#index"'
        end

        def add_application_controller_concern
          path = "app/controllers/application_controller.rb"
          return unless File.exist?(File.join(destination_root, path))
          inject_into_class path, "ApplicationController", "  include Authify::Authentication\n"
        end

        def create_task
          template "authify_tasks.rake.tt", "lib/tasks/authify_tasks.rake"
        end

        def create_security_tests
          template "tests/security_flows_test.rb.tt", "test/integration/authify_security_flows_test.rb"
          template "tests/hardening_test.rb.tt", "test/integration/authify_hardening_test.rb"
          template "tests/concurrency_test.rb.tt", "test/integration/authify_concurrency_test.rb"
        end

        private

        def user_model
          options[:user_model]
        end
      end
    end
  end
end
