# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/authify_rails"

class AuthifyTest < Minitest::Test
  def test_gem_entrypoint_loads_configuration_api
    assert_respond_to Authify, :configure
    assert_respond_to Authify, :configuration
  end

  def setup
    Authify.reset_configuration!
  end

  def test_default_configuration
    assert_equal 12, Authify.configuration.password_minimum_length
    assert_equal 128, Authify.configuration.password_maximum_length
    assert_equal true, Authify.configuration.pwned_password_check
    assert_equal false, Authify.configuration.pwned_fail_closed
    assert_equal "Your application", Authify.configuration.app_name
    assert_equal "no-reply@example.com", Authify.configuration.mailer_from
    assert_equal true, Authify.configuration.new_sign_in_notifications
  end

  def test_token_round_trip
    raw, digest = Authify::Token.generate

    assert Authify::Token.matches?(raw, digest)
    refute Authify::Token.matches?("wrong", digest)
  end

  def test_manifest_records_and_reloads_features
    Dir.mktmpdir do |root|
      manifest = Authify::InstallationManifest.new(root: root)
      refute manifest.installed?

      manifest.record!(
        version: "0.2.0",
        user_model: "User",
        views: "tailwind",
        features: %i[core roles]
      )

      reloaded = Authify::InstallationManifest.new(root: root)
      assert reloaded.installed?
      assert reloaded.feature?(:core)
      assert reloaded.feature?(:roles)
      refute reloaded.feature?(:api)
    end
  end

  def test_invalid_installation_manifest_fails_closed_without_overwriting_it
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      manifest_path = File.join(root, "config/authify.yml")
      ["features: [core]", "features: [unclosed"].each do |invalid_manifest|
        File.write(manifest_path, invalid_manifest)
        assert_raises(Authify::InstallationManifest::InvalidManifest) do
          Authify::InstallationManifest.new(root: root)
        end
        assert_equal invalid_manifest, File.read(manifest_path)
      end
    end
  end

  def test_upgrade_migration_is_additive_and_idempotent
    content = read_template("lib/generators/authify/upgrade/templates/compatibility_migration.rb.tt")

    assert_includes content, "unless column_exists?"
    assert_includes content, "unless index_name_exists?"
    assert_includes content, ":authentication_method"
    assert_includes content, ":remembered"
    refute_includes content, "remove_column"
  end

  def test_remembered_sessions_bypass_idle_timeout_but_keep_absolute_expiration
    migration = read_template("lib/generators/authify/internal/core/templates/migrations/create_authify_core.rb.tt")
    current_session = read_template("lib/generators/authify/internal/core/templates/current_session.rb.tt")
    session_model = read_template("lib/generators/authify/internal/core/templates/models/authify_session.rb.tt")

    assert_includes migration, "t.boolean :remembered, null: false, default: false"
    assert_includes current_session, "remembered: remember"
    assert_includes current_session, "expires: (remember ? duration.from_now : nil)"
    assert_includes session_model, "expires_at.future? && (remembered? || idle_valid?)"
  end

  def test_two_factor_sign_in_uses_a_separate_expiring_challenge
    sessions = read_template("lib/generators/authify/internal/core/templates/controllers/sessions_controller.rb.tt")
    challenge = read_template("lib/generators/authify/internal/core/templates/controllers/two_factor_challenges_controller.rb.tt")

    assert_includes sessions, "session[:authify_pending_two_factor]"
    assert_includes sessions, "redirect_to new_two_factor_challenge_path"
    refute_includes sessions, "params[:otp_code]"
    assert_includes challenge, "CHALLENGE_TTL = 5.minutes"
    assert_includes challenge, "verify?(params[:code])"
    assert_includes challenge, 'event_type: "sign_in_failed_2fa"'
  end

  def test_failed_login_updates_are_serialized_across_concurrent_requests
    concern = read_template("lib/generators/authify/internal/core/templates/concerns/authenticatable.rb.tt")

    # Database row locks prevent two simultaneous requests from losing
    # increments and exceeding the configured password/2FA guess budget.
    assert_includes concern, "def record_failed_login!"
    assert_includes concern, "with_lock do"
    assert_includes concern, "return if locked?"
    assert_includes concern, "update_columns(attrs)"
    assert_includes concern, "def clear_failed_logins!"
    refute_includes concern, "update_columns(**attrs, updated_at: Time.current)"
  end

  def test_unverified_users_cannot_start_or_resume_a_session
    sessions = read_template("lib/generators/authify/internal/core/templates/controllers/sessions_controller.rb.tt")
    current_session = read_template("lib/generators/authify/internal/core/templates/current_session.rb.tt")

    assert_includes sessions, "email_verification_required && !user.email_verified?"
    assert_includes sessions, "Verify your email address before signing in."
    assert_includes current_session, "email_verification_required && !record.user.email_verified?"
    assert_includes current_session, "record.revoke!"
  end

  def test_sign_in_notifications_require_both_a_new_ip_and_new_device
    event = read_template("lib/generators/authify/internal/core/templates/models/authentication_event.rb.tt")
    sessions = read_template("lib/generators/authify/internal/core/templates/controllers/sessions_controller.rb.tt")
    challenge = read_template("lib/generators/authify/internal/core/templates/controllers/two_factor_challenges_controller.rb.tt")

    assert_includes event, "SUCCESSFUL_SIGN_IN_TYPES"
    assert_includes event, "!prior_sign_ins.where(ip_address: ip_address).exists?"
    assert_includes event, "!prior_sign_ins.where(user_agent: user_agent).exists?"
    assert_includes sessions, "unique_sign_in = AuthenticationEvent.unique_sign_in_for?"
    assert_includes sessions, "if unique_sign_in && Authify.configuration.email_notifications_enabled"
    assert_includes challenge, "unique_sign_in = AuthenticationEvent.unique_sign_in_for?"
    assert_includes challenge, "send_new_sign_in_notification if unique_sign_in"
  end

  def test_email_changes_stay_pending_until_token_confirmation
    model = read_template("lib/generators/authify/internal/core/templates/concerns/authenticatable.rb.tt")
    controller = read_template("lib/generators/authify/internal/core/templates/controllers/email_changes_controller.rb.tt")

    assert_includes model, "pending_email: normalized"
    assert_includes model, "email_change_token_valid?"
    assert_includes controller, "email: user.pending_email"
    assert_includes controller, "email_verified_at: Time.current"
    assert_includes controller, "pending_email: nil"
    assert_includes controller, "user.authify_sessions.update_all(revoked_at: Time.current)"
    assert_includes controller, "require_sensitive_authentication"
    assert_includes controller, "rate_limit to: 5"
    assert_includes controller, "rate_limit to: 10"
    assert_includes controller, "email_change_requested.deliver_later"
    assert_includes controller, "def destroy"
    refute_includes controller, "metadata: { previous_email:"
  end

  def test_authenticated_password_change_revokes_sessions_and_notifies_user
    controller = read_template("lib/generators/authify/internal/core/templates/controllers/password_changes_controller.rb.tt")

    assert_includes controller, "require_authentication"
    assert_includes controller, "rate_limit to: 5"
    assert_includes controller, "authenticate(params[:current_password])"
    assert_includes controller, "password_confirmation"
    assert_includes controller, "must be different from your current password"
    assert_includes controller, "authify_sessions.update_all(revoked_at: Time.current)"
    assert_includes controller, 'event_type: "password_changed"'
    assert_includes controller, "password_changed.deliver_later"
    assert_includes controller, "reset_session"
  end

  def test_two_factor_template_requires_password_and_code_to_disable
    content = read_template("lib/generators/authify/internal/two_factor/templates/controller.rb.tt")

    assert_includes content, "password_ok = current_user.authenticate(params[:password]).present?"
    assert_includes content, "code_ok = credential.verify?(params[:code])"
    assert_includes content, "event_type: \"two_factor_disable_failed\""
    assert_includes content, "generate_recovery_codes!"
  end

  def test_recovery_codes_are_hashed_and_consumed_once
    model = read_template("lib/generators/authify/internal/two_factor/templates/model.rb.tt")
    challenge = read_template("lib/generators/authify/internal/core/templates/controllers/two_factor_challenges_controller.rb.tt")

    assert_includes model, "Authify::Token.digest"
    assert_includes model, "ActiveSupport::SecurityUtils.secure_compare"
    assert_includes model, "digests.delete_at(index)"
    assert_includes model, "with_lock"
    assert_includes challenge, "consume_recovery_code!"
    assert_includes challenge, '"recovery_code"'
  end

  def test_public_authentication_endpoints_are_rate_limited
    %w[sessions registrations passwords email_verifications two_factor_challenges].each do |name|
      content = read_template("lib/generators/authify/internal/core/templates/controllers/#{name}_controller.rb.tt")
      assert_includes content, "rate_limit to:"
    end
  end

  def test_sign_in_uses_dummy_bcrypt_for_missing_accounts
    content = read_template("lib/generators/authify/internal/core/templates/controllers/sessions_controller.rb.tt")

    assert_includes content, "DUMMY_PASSWORD_DIGEST"
    assert_includes content, "BCrypt::Password.new"
    assert_includes content, "authenticated && user.locked?"
  end

  def test_doctor_checks_production_security_dependencies
    content = read_template("lib/generators/authify/internal/core/templates/authify_tasks.rake.tt")

    assert_includes content, "Session authentication method exists"
    assert_includes content, "Remembered session field exists"
    assert_includes content, "Pending email fields exist"
    assert_includes content, "Active Record encryption primary key is configured"
    assert_includes content, "Shared cache store is configured"
  end

  def test_sudo_template_throttles_failed_attempts
    content = read_template("lib/generators/authify/internal/sudo/templates/controller.rb.tt")

    assert_includes content, "MAX_SUDO_ATTEMPTS = 5"
    assert_includes content, "before_action :block_if_sudo_locked, only: :create"
    assert_includes content, "increment_sudo_failures!"
    assert_includes content, "session[:authify_sudo_locked_until]"
  end

  def test_oauth_template_only_links_verified_provider_email
    content = read_template("lib/generators/authify/internal/oauth/templates/model.rb.tt")

    assert_includes content, "unless verified_email?(auth)"
    assert_includes content, "find_by(provider: auth.provider, uid: auth.uid)"
    assert_includes content, "find_by!(provider: auth.provider, uid: auth.uid)"

    controller = read_template("lib/generators/authify/internal/oauth/templates/controller.rb.tt")
    assert_includes controller, "active_two_factor_credential_for(user)"
    assert_includes controller, 'authentication_method: "oauth:#{identity.provider}"'
    assert_includes controller, "new_two_factor_challenge_path"
  end

  private

  def read_template(path)
    File.read(File.expand_path("../#{path}", __dir__))
  end
end
