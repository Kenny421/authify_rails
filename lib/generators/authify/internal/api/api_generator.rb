require "rails/generators"
require "rails/generators/active_record"
module Authify; module Generators; module Internal
  class ApiGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    class_option :user_model, type: :string, default: "User"
    def self.next_migration_number(dirname) = ActiveRecord::Generators::Base.next_migration_number(dirname)
    def generate_files
      migration_template "migration.rb.tt", "db/migrate/create_authify_api_tokens.rb"
      template "authentication.rb.tt", "app/controllers/concerns/authify/api_authentication.rb"
      template "model.rb.tt", "app/models/authify_api_token.rb"
      template "controller.rb.tt", "app/controllers/api/authify_tokens_controller.rb"
      inject_into_class "app/models/#{options[:user_model].underscore}.rb", options[:user_model], "  has_many :authify_api_tokens, foreign_key: :user_id, dependent: :destroy\n"
      route 'namespace :api do; resources :authify_tokens, only: %i[index create destroy]; end'
    end
  end
end; end; end
