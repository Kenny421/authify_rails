require "rails/generators"
module Authify; module Generators; module Internal
  class MultiTenantGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)
    class_option :user_model, type: :string, default: "User"
    def generate_files
      template "concern.rb.tt", "app/models/concerns/authify/tenant_scoped.rb"
      say "Multi-tenant concern generated. Add your tenant association and database index manually to match your app.", :yellow
    end
  end
end; end; end
