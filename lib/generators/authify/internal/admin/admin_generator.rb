require "authify/generator_views"
require "rails/generators"
module Authify; module Generators; module Internal
  class AdminGenerator < Rails::Generators::Base
    include Authify::GeneratorViews
    source_root File.expand_path("templates", __dir__)
    class_option :views, type: :string, default: "tailwind"
    def generate_files
      template "controller.rb.tt", "app/controllers/authify/admin/authentication_events_controller.rb"
      template "view.html.erb.tt", "app/views/authify/admin/authentication_events/index.html.erb" unless options[:views] == "none"
      plain_view!("app/views/authify/admin/authentication_events/index.html.erb")
      route 'namespace :authify do; namespace :admin do; resources :authentication_events, only: :index; end; end'
    end
  end
end; end; end
