require "rails/generators"
require "rails/generators/active_record"
module Authify
  module Generators
    module Internal
      class PasskeysGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        source_root File.expand_path("templates", __dir__)
        class_option :views, type: :string, default: "tailwind"
        class_option :user_model, type: :string, default: "User"
        def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
        def generate_files
          migration_template "migration.rb.tt", "db/migrate/create_authify_passkeys.rb"
          template "challenge.rb.tt", "app/models/authify_passkey_challenge.rb"
          template "model.rb.tt", "app/models/authify_passkey.rb"
          template "controller.rb.tt", "app/controllers/authify/passkeys_controller.rb"
          template "initializer.rb.tt", "config/initializers/authify_passkeys.rb"
          template "view.html.erb.tt", "app/views/authify/passkeys/index.html.erb" unless options[:views] == "none"
          copy_file "browser.js", "app/assets/javascripts/authify_passkeys.js"
          view = "app/views/authify/sessions/new.html.erb"
          if File.exist?(File.join(destination_root, view))
            append_to_file view, "\n<button type=\"button\" id=\"authify-sign-in-passkey\">Sign in with a passkey</button>\n<p id=\"authify-passkey-status\" role=\"status\"></p>\n<%= javascript_include_tag \"authify_passkeys\", defer: true %>\n"
          end
          inject_into_class "app/models/#{options[:user_model].underscore}.rb", options[:user_model], "  has_many :authify_passkeys, foreign_key: :user_id, dependent: :destroy\n"
          route <<~ROUTES
            scope module: :authify do
              resources :passkeys, only: %i[index create destroy] do
                post :registration_options, on: :collection
                post :authentication_options, on: :collection
                post :authenticate, on: :collection
              end
            end
          ROUTES
        end
      end
    end
  end
end
