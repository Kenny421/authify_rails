# frozen_string_literal: true

require "bundler"
require "rails/generators"
require "authify/installation_manifest"

module Authify
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      CORE_FEATURES = %i[core sessions registration password_reset email_verification mailer views security_events].freeze
      OPTIONAL_FEATURES = %i[oauth roles two_factor api sudo admin multi_tenant].freeze

      class_option :user_model, type: :string, default: "User", desc: "User model name"
      class_option :views, type: :string, default: "tailwind", enum: %w[tailwind plain none]
      class_option :roles, type: :boolean, default: false, desc: "Install role management"
      class_option :oauth, type: :boolean, default: false, desc: "Install Google, Facebook, and extensible OAuth sign-in"
      class_option :two_factor, type: :boolean, default: false, desc: "Install TOTP two-factor authentication"
      class_option :api, type: :boolean, default: false, desc: "Install personal API tokens"
      class_option :sudo, type: :boolean, default: false, desc: "Install step-up authentication"
      class_option :admin, type: :boolean, default: false, desc: "Install authentication-event admin pages"
      class_option :multi_tenant, type: :boolean, default: false, desc: "Install tenant-scoping concern"
      class_option :all, type: :boolean, default: false, desc: "Install every optional feature"
      class_option :skip_bundle, type: :boolean, default: false, desc: "Do not run bundle install"

      def explain_mode
        say manifest.installed? ? "Updating Authify installation..." : "Installing Authify...", :green
      end

      def validate_dependencies
        if enabled?(:admin) && !enabled_or_installed?(:roles)
          raise Thor::Error, "--admin requires --roles, or roles must already be installed."
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

        invoke "authify:internal:core", [], user_model: options[:user_model], views: options[:views]
      end

      def install_optional_features
        invoke_feature(:oauth, "authify:internal:oauth", user_model: options[:user_model], views: options[:views])
        invoke_feature(:roles, "authify:internal:roles", user_model: options[:user_model])
        invoke_feature(:two_factor, "authify:internal:two_factor", user_model: options[:user_model])
        invoke_feature(:api, "authify:internal:api", user_model: options[:user_model])
        invoke_feature(:sudo, "authify:internal:sudo")
        invoke_feature(:admin, "authify:internal:admin")
        invoke_feature(:multi_tenant, "authify:internal:multi_tenant", user_model: options[:user_model])
      end

      def install_flash_messages
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
          user_model: options[:user_model],
          views: options[:views],
          features: features
        )
      end

      def summary
        newly_selected = OPTIONAL_FEATURES.select { |name| enabled?(name) && !@previous_features.include?(name) }
        say "\nAuthify is ready.", :green
        say "Installed features: #{manifest.features.sort.join(', ')}"
        say "No new optional features were requested." if manifest.installed? && newly_selected.empty?
        say "\nNext steps:\n  bin/rails db:migrate\n  bin/rails authify:doctor\n"
      end

      private

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
