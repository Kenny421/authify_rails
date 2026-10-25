# frozen_string_literal: true

require "bundler"
require "rails/generators"
require "authify/installation_manifest"
require "authify/template_catalog"

module Authify
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      CORE_FEATURES = %i[core sessions registration password_reset email_verification mailer views security_events].freeze
      OPTIONAL_FEATURES = %i[oauth roles two_factor api sudo admin passkeys multi_tenant].freeze

      class_option :user_model, type: :string, default: "User", desc: "User model name"
      class_option :views, type: :string, default: "tailwind", enum: %w[tailwind plain none]
      class_option :roles, type: :boolean, default: false, desc: "Install role management"
      class_option :oauth, type: :boolean, default: false, desc: "Install Google, Facebook, and extensible OAuth sign-in"
      class_option :two_factor, type: :boolean, default: false, desc: "Install TOTP two-factor authentication"
      class_option :api, type: :boolean, default: false, desc: "Install personal API tokens"
      class_option :sudo, type: :boolean, default: false, desc: "Install step-up authentication"
      class_option :admin, type: :boolean, default: false, desc: "Install authentication-event admin pages"
      class_option :multi_tenant, type: :boolean, default: false, desc: "Install tenant-scoping concern"
      class_option :passkeys, type: :boolean, default: false, desc: "Install WebAuthn passkeys"
      class_option :all, type: :boolean, default: false, desc: "Install every optional feature"
      class_option :skip_bundle, type: :boolean, default: false, desc: "Do not run bundle install"

      def explain_mode
        say manifest.installed? ? "Updating Authify installation..." : "Installing Authify...", :green
      end

      def validate_dependencies
        if manifest.feature?(:core) && manifest.version != Authify::VERSION
          raise Thor::Error, "Upgrade existing generated files first: bin/rails generate authify:upgrade --dry-run"
        end
        if manifest.installed? && manifest.feature?(:core)
          if user_model_name != "User" && user_model_name != manifest.user_model
            raise Thor::Error, "Installed user model is #{manifest.user_model}; changing it requires a manual migration."
          end
          @effective_user_model = manifest.user_model
          @effective_views = manifest.views
          say "Keeping installed views=#{manifest.views}; use the upgrade preview to review template changes." if options[:views] != manifest.views
        end
        if enabled?(:admin) && !enabled_or_installed?(:roles)
          raise Thor::Error, "--admin requires --roles, or roles must already be installed."
        end
      end

      def preflight_existing_authentication
        return if manifest.feature?(:core)
        model = File.join(destination_root, "app/models/#{user_model_name.underscore}.rb")
        controller = File.join(destination_root, "app/controllers/application_controller.rb")
        routes = File.join(destination_root, "config/routes.rb")
        source = File.file?(model) ? File.read(model) : ""
        if source.match?(/\bdevise\b|acts_as_authentic|authenticates_with_sorcery!|has_secure_password/)
          raise Thor::Error, "Existing authentication found in #{model}. Review an explicit migration to Authify; installation stopped before writes."
        end
        if File.file?(controller) && File.read(controller).match?(/include\s+Authentication\b|authenticate_user!/)
          raise Thor::Error, "Existing authentication controller integration found. Review compatibility before installing Authify."
        end
        if File.file?(routes) && File.read(routes).match?(/resource[s]?\s+:sessions?\b|as:\s*:new_session\b|devise_for/)
          raise Thor::Error, "Existing authentication routes found. Review route conflicts before installing Authify."
        end
      end

      def add_dependencies
        gem "bcrypt", "~> 3.1" unless gem_declared?("bcrypt")
        if enabled?(:oauth)
          gem "omniauth", "~> 2.1" unless gem_declared?("omniauth")
          gem "omniauth-rails_csrf_protection", "~> 1.0" unless gem_declared?("omniauth-rails_csrf_protection")
          gem "omniauth-google-oauth2", "~> 1.2" unless gem_declared?("omniauth-google-oauth2")
          gem "omniauth-facebook", "~> 10.0" unless gem_declared?("omniauth-facebook")
        end
        gem "webauthn", "~> 3.0" if enabled?(:passkeys) && !gem_declared?("webauthn")
        gem "rotp", "~> 6.3" if enabled?(:two_factor) && !gem_declared?("rotp")
        gem "rqrcode", ">= 3.1", "< 4" if enabled?(:two_factor) && !gem_declared?("rqrcode")
      end

      def bundle_dependencies
        return if options[:skip_bundle]
        return unless dependencies_changed?

        Bundler.with_unbundled_env { run "bundle install" }
      end

      def install_core
        return if manifest.feature?(:core)
        if manifest.installed?
          raise Thor::Error, "Existing Authify initializer without installation metadata. Restore config/authify.yml before installing."
        end

        invoke "authify:internal:core", [], user_model: user_model_name, views: view_style
      end

      def install_optional_features
        invoke_feature(:oauth, "authify:internal:oauth", user_model: user_model_name, views: view_style)
        invoke_feature(:roles, "authify:internal:roles", user_model: user_model_name)
        invoke_feature(:two_factor, "authify:internal:two_factor", user_model: user_model_name, views: view_style)
        invoke_feature(:api, "authify:internal:api", user_model: user_model_name)
        invoke_feature(:sudo, "authify:internal:sudo", views: view_style)
        invoke_feature(:admin, "authify:internal:admin", views: view_style)
        invoke_feature(:passkeys, "authify:internal:passkeys", user_model: user_model_name, views: view_style)
        invoke_feature(:multi_tenant, "authify:internal:multi_tenant", user_model: user_model_name)
      end

      def install_flash_messages
        return if view_style == "none"
        partial = "app/views/authify/shared/_flash.html.erb"
        template "flash.html.erb.tt", partial unless File.exist?(File.join(destination_root, partial))

        layout = "app/views/layouts/application.html.erb"
        layout_path = File.join(destination_root, layout)
        unless File.exist?(layout_path)
          return say_status(:skip, "#{layout} not found; render authify/shared/flash from your application layout")
        end

        return say_status(:identical, "Authify flash renderer") if File.read(layout_path).include?('render "authify/shared/flash"')

        inject_into_file layout, "\n    <%= render \"authify/shared/flash\" %>", after: /<body[^>]*>/
      end

      def write_manifest
        features = []
        features.concat(CORE_FEATURES) unless manifest.feature?(:core)
        features.concat(OPTIONAL_FEATURES.select { |feature| enabled?(feature) })
        manifest.record!(
          version: Authify::VERSION,
          user_model: user_model_name,
          views: view_style,
          features: features
        )
        catalog = Authify::TemplateCatalog.new(user_model: user_model_name, views: view_style, features: manifest.features).files
        # Only claim ownership where the generated file exactly matches a known template.
        baselines = manifest.baselines.dup
        catalog.each do |path, content|
          actual = File.join(destination_root, path)
          baselines[path] ||= content if File.file?(actual) && File.read(actual) == content
        end
        manifest.record_baselines!(baselines)
      end

      def summary
        newly_selected = OPTIONAL_FEATURES.select { |name| enabled?(name) && !@previous_features.include?(name) }
        say "\nAuthify is ready.", :green
        say "Installed features: #{manifest.features.sort.join(', ')}"
        say "No new optional features were requested." if manifest.installed? && newly_selected.empty?
        say "\nNext steps:\n  bin/rails db:migrate\n  bin/rails authify:doctor\n"
      end

      private

      def user_model_name = @effective_user_model || options[:user_model]
      def view_style = @effective_views || options[:views]

      def manifest
        @manifest ||= begin
          value = Authify::InstallationManifest.new(root: destination_root)
          @previous_features = value.features
          value
        end
      end

      def enabled?(name)
        options[:all] || options[name]
      end

      def enabled_or_installed?(name)
        enabled?(name) || manifest.feature?(name)
      end

      def invoke_feature(name, generator, **generator_options)
        return unless enabled?(name)
        return say_status(:identical, "Authify #{name.to_s.tr('_', ' ')} already installed") if manifest.feature?(name)

        invoke generator, [], generator_options
      end

      def gem_declared?(name)
        gemfile = File.join(destination_root, "Gemfile")
        File.exist?(gemfile) && File.read(gemfile).match?(/^\s*gem\s+["']#{Regexp.escape(name)}["']/)
      end

      def dependencies_changed?
        previous = manifest.features
        OPTIONAL_FEATURES.any? { |feature| enabled?(feature) && !previous.include?(feature) } || !manifest.installed?
      end
    end
  end
end
