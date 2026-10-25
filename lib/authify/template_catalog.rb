# frozen_string_literal: true
require "erb"
require "authify/generator_views"

module Authify
  # Only Authify-owned files are upgrade candidates. Integration files (routes,
  # ApplicationController, User, Gemfile and application layout) are never replaced.
  class TemplateCatalog
    def initialize(user_model:, views:, features:, legacy: false)
      @options = { user_model: user_model, views: views }
      @features = features.map(&:to_sym)
      @root = legacy ? File.join(__dir__, "legacy/0.3.0/lib/generators/authify") : File.expand_path("../generators/authify", __dir__)
      @legacy = legacy
    end

    def files
      map = {}
      core = "internal/core/templates"
      %w[authentication current_session abuse_guard sensitive_authentication].each { |n| map["app/controllers/concerns/authify/#{n}.rb"] = "#{core}/#{n}.rb.tt" }
      %w[authenticatable secure_password].each { |n| map["app/models/concerns/authify/#{n}.rb"] = "#{core}/concerns/#{n}.rb.tt" }
      %w[authify_session authentication_event authify_abuse_bucket authify_sign_in_challenge].each { |n| map["app/models/#{n}.rb"] = "#{core}/models/#{n}.rb.tt" }
      %w[application sessions two_factor_challenges registrations passwords password_changes email_verifications email_changes account_sessions].each do |n|
        map["app/controllers/authify/#{n}_controller.rb"] = "#{core}/controllers/#{n}_controller.rb.tt"
      end
      map["config/initializers/authify_abuse.rb"] = "#{core}/authify_abuse.rb.tt"
      map["app/assets/javascripts/authify_turnstile.js"] = "#{core}/authify_turnstile.js"
      map["app/models/current.rb"] = "#{core}/current.rb.tt"
      map["app/mailers/authify_mailer.rb"] = "#{core}/mailer.rb.tt"
      map["test/mailers/previews/authify_mailer_preview.rb"] = "#{core}/mailer_preview.rb.tt"
      map["test/integration/authify_abuse_test.rb"] = "#{core}/tests/abuse_test.rb.tt"
      map["test/integration/authify_concurrency_test.rb"] = "#{core}/tests/concurrency_test.rb.tt"
      map["test/integration/authify_hardening_test.rb"] = "#{core}/tests/hardening_test.rb.tt"
      map["test/integration/authify_security_flows_test.rb"] = "#{core}/tests/security_flows_test.rb.tt"
      map["lib/tasks/authify_tasks.rake"] = "#{core}/authify_tasks.rake.tt"
      Dir.glob(File.join(@root, core, "mailer_views/*")).reject { |f| f.include?(":Zone.Identifier") }.each do |file|
        name = File.basename(file, ".tt")
        target = name.start_with?("layout.") ? "app/views/layouts/authify_mailer.#{name.split('.', 2).last}" : "app/views/authify_mailer/#{name}"
        map[target] = file.delete_prefix("#{@root}/")
      end
      unless @options[:views] == "none"
        directory = !@legacy && @options[:views] == "plain" ? "plain_views" : "views"
        Dir.glob(File.join(@root, core, directory, "**/*.erb")).each do |file|
          map["app/views/authify/#{file.split("/#{directory}/", 2).last}"] = file.delete_prefix("#{@root}/")
        end
      end
      feature_files = {
        api: { "model.rb.tt" => "app/models/authify_api_token.rb", "controller.rb.tt" => "app/controllers/api/authify_tokens_controller.rb", "authentication.rb.tt" => "app/controllers/concerns/authify/api_authentication.rb" },
        two_factor: { "compatibility_controller.rb.tt" => "app/controllers/authify/two_factors_controller.rb", "model.rb.tt" => "app/models/authify_two_factor_credential.rb", "controller.rb.tt" => "app/controllers/authify/two_factor_controller.rb", "view.html.erb.tt" => "app/views/authify/two_factor/new.html.erb" },
        sudo: { "compatibility_controller.rb.tt" => "app/controllers/authify/sudos_controller.rb", "concern.rb.tt" => "app/controllers/concerns/authify/sudo.rb", "controller.rb.tt" => "app/controllers/authify/sudo_controller.rb", "view.html.erb.tt" => "app/views/authify/sudo/new.html.erb" },
        oauth: { "model.rb.tt" => "app/models/authify_oauth_identity.rb", "controller.rb.tt" => "app/controllers/authify/oauth_callbacks_controller.rb", "test.rb.tt" => "test/integration/authify_oauth_security_test.rb", "buttons.html.erb.tt" => "app/views/authify/shared/_oauth_buttons.html.erb" },
        roles: { "role.rb.tt" => "app/models/authify_role.rb", "assignment.rb.tt" => "app/models/authify_role_assignment.rb" },
        multi_tenant: { "initializer.rb.tt" => "config/initializers/authify_tenant.rb" },
        passkeys: { "model.rb.tt" => "app/models/authify_passkey.rb", "challenge.rb.tt" => "app/models/authify_passkey_challenge.rb", "controller.rb.tt" => "app/controllers/authify/passkeys_controller.rb", "view.html.erb.tt" => "app/views/authify/passkeys/index.html.erb", "browser.js" => "app/assets/javascripts/authify_passkeys.js" },
        admin: { "controller.rb.tt" => "app/controllers/authify/admin/authentication_events_controller.rb", "view.html.erb.tt" => "app/views/authify/admin/authentication_events/index.html.erb" }
      }
      feature_files.each do |feature, entries|
        next unless @features.include?(feature)
        entries.each do |source, target|
          next if target.start_with?("app/views/") && @options[:views] == "none"
          map[target] = "internal/#{feature}/templates/#{source}"
        end
      end
      map.filter_map do |target, source|
        path = File.join(@root, source)
        next unless File.file?(path)
        text = File.read(path)
        text = ERB.new(text, trim_mode: "-").result(binding) if source.end_with?(".tt")
        if @features.include?(:oauth) && target.match?(%r{app/views/authify/(sessions|registrations)/new.html.erb$})
          text += "\n<%= render \"authify/shared/oauth_buttons\" %>\n"
        end
        if !@legacy && @features.include?(:passkeys) && target == "app/views/authify/sessions/new.html.erb"
          text += "\n<button type=\"button\" id=\"authify-sign-in-passkey\">Sign in with a passkey</button>\n<p id=\"authify-passkey-status\" role=\"status\"></p>\n<%= javascript_include_tag \"authify_passkeys\", defer: true %>\n"
        end
        text = Authify::GeneratorViews.plain(text) if !@legacy && @options[:views] == "plain" && target.start_with?("app/views/")
        [target, text]
      end.to_h
    end

    private
    def options = @options
  end
end
