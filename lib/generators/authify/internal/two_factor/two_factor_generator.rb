require "authify/generator_views"
require "rails/generators"
require "rails/generators/active_record"
module Authify; module Generators; module Internal
  class TwoFactorGenerator < Rails::Generators::Base
    include Authify::GeneratorViews
    include Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    class_option :views, type: :string, default: "tailwind"
    class_option :user_model, type: :string, default: "User"
    def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
    def generate_files
      migration_template "migration.rb.tt", "db/migrate/create_authify_two_factor_credentials.rb"
      template "model.rb.tt", "app/models/authify_two_factor_credential.rb"
      template "controller.rb.tt", "app/controllers/authify/two_factor_controller.rb"
      inject_into_class "app/models/#{options[:user_model].underscore}.rb", options[:user_model], "  has_one :authify_two_factor_credential, foreign_key: :user_id, dependent: :destroy\n"
      template "view.html.erb.tt", "app/views/authify/two_factor/new.html.erb" unless options[:views] == "none"
      plain_view!("app/views/authify/two_factor/new.html.erb")
      route 'scope module: :authify do; resource :two_factor, only: %i[new create destroy] do; post :recovery_codes; end; end'
    end
  end
end; end; end
