# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/authify"
require_relative "../lib/generators/authify/internal/core/core_generator"
require_relative "../lib/generators/authify/internal/two_factor/two_factor_generator"
require_relative "../lib/generators/authify/internal/sudo/sudo_generator"
require_relative "../lib/generators/authify/internal/oauth/oauth_generator"
require_relative "../lib/generators/authify/internal/admin/admin_generator"
require_relative "../lib/generators/authify/install/install_generator"
require_relative "../lib/generators/authify/upgrade/upgrade_generator"

class GeneratorIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("authify-generator-test")
    build_fake_app!
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_core_generator_writes_staged_2fa_sign_in_flow
    run_generator(Authify::Generators::Internal::CoreGenerator, ["--user-model=User", "--views=tailwind"])

    sessions_controller = read_generated("app/controllers/authify/sessions_controller.rb")
    sessions_view = read_generated("app/views/authify/sessions/new.html.erb")
    challenge_controller = read_generated("app/controllers/authify/two_factor_challenges_controller.rb")
    challenge_view = read_generated("app/views/authify/two_factor_challenges/new.html.erb")
    email_changes_controller = read_generated("app/controllers/authify/email_changes_controller.rb")
    email_changes_view = read_generated("app/views/authify/email_changes/edit.html.erb")
    password_changes_controller = read_generated("app/controllers/authify/password_changes_controller.rb")
    password_changes_view = read_generated("app/views/authify/password_changes/edit.html.erb")

    assert_includes sessions_controller, "active_two_factor_credential_for(user)"
    assert_includes sessions_controller, "respond_to?(:authify_two_factor_credential)"
    assert_includes sessions_controller, "redirect_to new_two_factor_challenge_path"
    assert_includes sessions_controller, "email_verification_required && !user.email_verified?"
    refute_includes sessions_view, "Authenticator code"
    assert_includes challenge_controller, "CHALLENGE_TTL = 5.minutes"
    assert_includes challenge_controller, "verify?(params[:code])"
    assert_includes challenge_controller, 'event_type: "sign_in_failed_2fa"'
    assert_includes challenge_view, "Authenticator or recovery code"
    assert_includes email_changes_controller, "request_email_change!"
    assert_includes email_changes_controller, "email: user.pending_email"
    assert_includes email_changes_controller, "authify_sensitive_authentication"
    assert_includes email_changes_controller, "email_changed.deliver_later"
    assert_includes email_changes_view, "current email remains active"
    assert_includes email_changes_view, "Cancel email change"
    assert_includes password_changes_controller, "authenticate(params[:current_password])"
    assert_includes password_changes_controller, "authify_sessions.update_all"
    assert_includes password_changes_view, "Changing your password signs out every device."

    mailer_view = read_generated("app/views/authify_mailer/email_verification.html.erb")
    assert_includes mailer_view, '<% content_for :preheader'
    assert_includes mailer_view, "<%= @action_url %>"

    home_controller = read_generated("app/controllers/home_controller.rb")
    home_view = read_generated("app/views/home/index.html.erb")
    routes = read_generated("config/routes.rb")
    security_tests = read_generated("test/integration/authify_security_flows_test.rb")
    assert_includes home_controller, "class HomeController < ApplicationController"
    assert_includes home_view, "<% if authenticated? %>"
    assert_includes routes, 'root "home#index"'
    assert_includes routes, 'get "/sign-in"'
    assert_includes routes, 'get "/sign-up"'
    assert_includes routes, 'delete "/sign-out"'
    assert_includes routes, 'get "/forgot-password"'
    assert_includes routes, 'get "/reset-password/:token"'
    assert_includes routes, 'get "/account/password"'
    assert_includes routes, 'get "/verify-email/:token"'
    assert_includes routes, 'get "/account/email"'
    assert_includes routes, 'get "/confirm-email-change/:token"'
    refute_includes routes, "resource :session"
    refute File.exist?(File.join(@tmpdir, "app/views/authify/home/index.html.erb"))
    assert_includes security_tests, "class AuthifySecurityFlowsTest < ActionDispatch::IntegrationTest"
    assert_includes security_tests, "unverified user cannot create a session"
    assert_includes security_tests, "does not reveal whether account exists"
    assert_includes security_tests, "remembered session survives idle timeout"
    assert_includes security_tests, "session without remember me expires after idle timeout"
    assert_includes security_tests, "remembered session expires after remember me duration"
  end

  def test_core_generator_preserves_an_existing_root_route_and_home_page
    File.write(File.join(@tmpdir, "app/controllers/home_controller.rb"), "class HomeController < ApplicationController\nend\n")
    FileUtils.mkdir_p(File.join(@tmpdir, "app/views/home"))
    File.write(File.join(@tmpdir, "app/views/home/index.html.erb"), "Existing home\n")
    File.write(File.join(@tmpdir, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        root "dashboard#index"
      end
    RUBY

    run_generator(Authify::Generators::Internal::CoreGenerator, ["--user-model=User", "--views=tailwind"])

    assert_equal "class HomeController < ApplicationController\nend\n",
                 read_generated("app/controllers/home_controller.rb")
    assert_equal "Existing home\n", read_generated("app/views/home/index.html.erb")
    assert_includes read_generated("config/routes.rb"), 'root "dashboard#index"'
    refute_includes read_generated("config/routes.rb"), 'root "home#index"'
  end

  def test_two_factor_generator_writes_secure_disable_flow
    run_generator(Authify::Generators::Internal::CoreGenerator, ["--user-model=User", "--views=tailwind"])
    run_generator(Authify::Generators::Internal::TwoFactorGenerator, ["--user-model=User"])

    two_factor_controller = read_generated("app/controllers/authify/two_factor_controller.rb")
    two_factor_view = read_generated("app/views/authify/two_factor/new.html.erb")

    assert_includes two_factor_controller, "authify_sensitive_authentication(password: params[:password], allow_recent: false)"
    assert_includes two_factor_controller, "current_user.authify_invalidate_credentials!"
    assert_includes two_factor_controller, "event_type: \"two_factor_disabled\""
    assert_includes two_factor_controller, "generate_recovery_codes!"
    assert_includes two_factor_view, "method: :delete"
    assert_includes two_factor_view, "Disable two-factor"
    assert_includes two_factor_view, "Save these recovery codes now"
  end

  def test_sudo_generator_writes_lockout_controls
    run_generator(Authify::Generators::Internal::CoreGenerator, ["--user-model=User", "--views=tailwind"])
    run_generator(Authify::Generators::Internal::SudoGenerator)

    sudo_controller = read_generated("app/controllers/authify/sudo_controller.rb")

    assert_includes sudo_controller, "authify_sensitive_authentication"
    assert_includes sudo_controller, "allow_recent: false"
    assert_includes sudo_controller, "rate_limit to: 10"
    assert_includes sudo_controller, "event_type: \"sudo_failed\""
  end

  def test_oauth_generator_writes_provider_agnostic_secure_sign_in
    run_generator(Authify::Generators::Internal::CoreGenerator, ["--user-model=User", "--views=tailwind"])
    run_generator(Authify::Generators::Internal::OauthGenerator, ["--user-model=User", "--views=tailwind"])

    identity = read_generated("app/models/authify_oauth_identity.rb")
    controller = read_generated("app/controllers/authify/oauth_callbacks_controller.rb")
    initializer = read_generated("config/initializers/authify_oauth.rb")
    session_view = read_generated("app/views/authify/sessions/new.html.erb")
    routes = read_generated("config/routes.rb")
    oauth_tests = read_generated("test/integration/authify_oauth_security_test.rb")

    assert_includes identity, "validates :uid, uniqueness: { scope: :provider }"
    assert_includes identity, "unless verified_email?(auth)"
    assert_includes identity, "rescue ActiveRecord::RecordNotUnique"
    assert_includes controller, 'request.env.fetch("omniauth.auth")'
    assert_includes controller, "user.disabled_at.present? || user.locked?"
    assert_includes controller, "active_two_factor_credential_for(user)"
    assert_includes controller, 'authentication_method: "oauth:#{identity.provider}"'
    assert_includes initializer, "provider :google_oauth2"
    assert_includes initializer, "provider :facebook"
    assert_includes initializer, "allowed_request_methods = %i[post]"
    assert_includes session_view, 'render "authify/shared/oauth_buttons"'
    assert_includes routes, '"/auth/:provider/callback"'
    assert_includes oauth_tests, '"unverified provider email is rejected"'
    assert_includes oauth_tests, '"oauth:google_oauth2"'
  end

  def test_admin_generator_preserves_runtime_erb_in_events_view
    run_generator(Authify::Generators::Internal::AdminGenerator)

    view = read_generated("app/views/authify/admin/authentication_events/index.html.erb")

    assert_includes view, "<% @events.each do |event| %>"
    assert_includes view, "<%= event.event_type %>"
    assert_includes view, "<% end %>"
  end

  def test_all_features_install_to_completion
    run_generator(
      Authify::Generators::InstallGenerator,
      ["--all", "--skip-bundle", "--user-model=User", "--views=tailwind"]
    )

    manifest = read_generated("config/authify.yml")

    assert_includes manifest, "oauth: true"
    assert_includes manifest, "admin: true"
    assert_includes manifest, "multi_tenant: true"
    assert_includes read_generated("app/views/layouts/application.html.erb"),
                    '<%= render "authify/shared/flash" %>'
    assert_includes read_generated("app/views/authify/shared/_flash.html.erb"), "flash.each"

    run_generator(
      Authify::Generators::InstallGenerator,
      ["--all", "--skip-bundle", "--user-model=User", "--views=tailwind"]
    )
    assert_equal 1, read_generated("app/views/layouts/application.html.erb").scan("authify/shared/flash").length

    run_generator(Authify::Generators::UpgradeGenerator)
    migration_path = Dir[File.join(@tmpdir, "db/migrate/*_upgrade_authify_040_security_fields.rb")].first
    refute_nil migration_path
    migration = File.read(migration_path)
    assert_includes migration, "user_table = :users"
    assert_includes migration, "column_exists?(:authify_sessions, :authentication_method)"
    assert RubyVM::InstructionSequence.compile(migration)
  end

  private

  def run_generator(generator_class, args = [])
    generator_class.start(args, destination_root: @tmpdir, behavior: :invoke)
  end

  def read_generated(path)
    File.read(File.join(@tmpdir, path))
  end

  def build_fake_app!
    FileUtils.mkdir_p(File.join(@tmpdir, "config"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app/models"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app/controllers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app/views/layouts"))
    File.write(File.join(@tmpdir, "Gemfile"), "source \"https://rubygems.org\"\n")
    File.write(File.join(@tmpdir, "app/views/layouts/application.html.erb"), <<~ERB)
      <!DOCTYPE html>
      <html>
        <body>
          <%= yield %>
        </body>
      </html>
    ERB

    File.write(File.join(@tmpdir, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
      end
    RUBY

    File.write(File.join(@tmpdir, "app/models/user.rb"), <<~RUBY)
      class User < ApplicationRecord
      end
    RUBY

    File.write(File.join(@tmpdir, "app/controllers/application_controller.rb"), <<~RUBY)
      class ApplicationController < ActionController::Base
      end
    RUBY
  end
end

class GeneratorIntegrationTest
  def test_legacy_upgrade_preserves_customizations_and_preview_is_read_only
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle", "--user-model=Member", "--views=plain"])
    manifest_path = File.join(@tmpdir, "config/authify.yml")
    data = YAML.safe_load_file(manifest_path)
    data["version"] = "0.3.0"
    data.delete("files")
    File.write(manifest_path, YAML.dump(data))
    legacy = Authify::TemplateCatalog.new(user_model: "Member", views: "plain", features: [:core], legacy: true).files
    legacy.each do |path, content|
      FileUtils.mkdir_p(File.dirname(File.join(@tmpdir, path)))
      File.write(File.join(@tmpdir, path), content)
    end
    path = File.join(@tmpdir, "app/controllers/authify/sessions_controller.rb")
    File.open(path, "a") { |file| file.puts "# application's custom sign-in hook" }
    before = snapshot_app
    run_generator(Authify::Generators::UpgradeGenerator, ["--dry-run"])
    assert_equal before, snapshot_app
    run_generator(Authify::Generators::UpgradeGenerator)
    assert_includes File.read(path), "# application's custom sign-in hook"
    assert_includes read_generated("app/controllers/concerns/authify/current_session.rb"), "record.user.disabled_at.present?"
    assert_equal "0.4.0", YAML.safe_load_file(manifest_path)["version"]
    after = snapshot_app
    run_generator(Authify::Generators::UpgradeGenerator)
    assert_equal after, snapshot_app
  end

  def test_upgrade_conflict_preserves_every_application_file_and_version
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle"])
    manifest_path = File.join(@tmpdir, "config/authify.yml")
    data = YAML.safe_load_file(manifest_path)
    data["version"] = "0.3.0"
    data.delete("files")
    File.write(manifest_path, YAML.dump(data))
    path = File.join(@tmpdir, "app/controllers/concerns/authify/current_session.rb")
    File.write(path, "# completely customized session management\n")
    before = snapshot_app
    run_generator(Authify::Generators::UpgradeGenerator)
    assert_equal before, snapshot_app
    assert File.exist?(File.join(@tmpdir, ".authify/upgrade/app/controllers/concerns/authify/current_session.rb.proposed"))
    assert_equal "0.3.0", YAML.safe_load_file(manifest_path)["version"]
  end

  def test_plain_views_do_not_include_tailwind_classes
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle", "--views=plain"])
    refute_includes read_generated("app/views/authify/sessions/new.html.erb"), "class:"
    refute_includes read_generated("app/views/authify/sessions/new.html.erb"), 'class="'
  end

  def test_adding_a_feature_keeps_the_installed_custom_user_model
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle", "--user-model=Member"])
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle", "--api"])
    assert_includes read_generated("app/models/member.rb"), "has_many :authify_api_tokens"
    refute File.exist?(File.join(@tmpdir, "app/models/user.rb")) && read_generated("app/models/user.rb").include?("authify_api_tokens")
    assert_equal "Member", YAML.safe_load_file(File.join(@tmpdir, "config/authify.yml"))["user_model"]
  end

  private
  def snapshot_app
    Dir[File.join(@tmpdir, "**/*")].select { |p| File.file?(p) }.to_h { |p| [p.delete_prefix(@tmpdir), File.binread(p)] }
  end
end

class GeneratorIntegrationTest
  def test_no_view_install_does_not_generate_optional_pages_or_inject_flash
    run_generator(Authify::Generators::InstallGenerator, ["--all", "--skip-bundle", "--views=none"])
    assert_empty Dir[File.join(@tmpdir, "app/views/authify/**/*.erb")]
    refute_includes read_generated("app/views/layouts/application.html.erb"), "authify/shared/flash"
  end
end

class GeneratorIntegrationTest
  def test_existing_authentication_stops_installation_before_writes
    File.write(File.join(@tmpdir, "app/models/user.rb"), "class User < ApplicationRecord\n  has_secure_password\nend\n")
    before = snapshot_app
    run_generator(Authify::Generators::InstallGenerator, ["--skip-bundle"])
    assert_equal before, snapshot_app
    refute File.exist?(File.join(@tmpdir, "config/authify.yml"))
  end
end
