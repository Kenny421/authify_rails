# frozen_string_literal: true

module Authify
  class Configuration
    attr_accessor :user_class_name, :session_class_name, :mailer_class_name,
                  :password_minimum_length, :password_maximum_length,
                  :password_reset_ttl, :email_verification_ttl,
                  :email_change_request_cooldown,
                  :session_idle_timeout, :session_absolute_timeout,
                  :remember_me_duration, :pwned_password_check,
                  :pwned_fail_closed, :pwned_timeout,
                  :maximum_login_attempts, :lockout_duration,
                  :sudo_timeout, :after_sign_in_path, :after_sign_out_path,
                  :email_verification_required, :app_name, :company_name,
                  :support_email, :mailer_from, :logo_url, :primary_color,
                  :email_footer_text, :email_notifications_enabled,
                  :new_sign_in_notifications, :password_change_notifications, :api_scopes, :tenant_enabled, :tenant_key, :tenant_resolver, :abuse_window, :abuse_source_request_limit,
                  :abuse_source_failure_threshold, :abuse_pair_challenge_threshold,
                  :abuse_pair_cooldown_threshold, :abuse_account_failure_threshold,
                  :abuse_spray_threshold, :abuse_account_request_limit, :abuse_device_lifetime,
                  :abuse_public_source_challenge_threshold,
                  :bot_challenge_verifier, :bot_challenge_partial, :turnstile_site_key

    attr_reader :abuse_mode

    def initialize
      @abuse_mode = :observe
      @abuse_window = 10.minutes
      @abuse_source_request_limit = 300
      @abuse_source_failure_threshold = 30
      @abuse_pair_challenge_threshold = 5
      @abuse_pair_cooldown_threshold = 10
      @abuse_account_failure_threshold = 10
      @abuse_spray_threshold = 10
      @abuse_account_request_limit = 5
      @abuse_public_source_challenge_threshold = 5
      @abuse_device_lifetime = 30.days
      @bot_challenge_verifier = nil
      @bot_challenge_partial = nil
      @turnstile_site_key = nil
      @tenant_enabled = false
      @tenant_key = :tenant_id
      @tenant_resolver = nil
      @api_scopes = []
      @user_class_name = "User"
      @session_class_name = "AuthifySession"
      @mailer_class_name = "AuthifyMailer"
      @password_minimum_length = 12
      @password_maximum_length = 128
      @password_reset_ttl = 30.minutes
      @email_verification_ttl = 24.hours
      @email_change_request_cooldown = 1.minute
      @session_idle_timeout = 30.minutes
      @session_absolute_timeout = 30.days
      @remember_me_duration = 30.days
      @pwned_password_check = true
      @pwned_fail_closed = false
      @pwned_timeout = 3.seconds
      @maximum_login_attempts = 5
      @lockout_duration = 15.minutes
      @sudo_timeout = 10.minutes
      @after_sign_in_path = "/"
      @after_sign_out_path = "/"
      @email_verification_required = true
      @app_name = "Your application"
      @company_name = "Your company"
      @support_email = nil
      @mailer_from = "no-reply@example.com"
      @logo_url = nil
      @primary_color = "#111827"
      @email_footer_text = nil
      @email_notifications_enabled = true
      @new_sign_in_notifications = true
      @password_change_notifications = true
    end

    def abuse_mode=(value)
      mode = value.to_sym
      raise ArgumentError, "Authify abuse_mode must be off, observe or enforce" unless %i[off observe enforce].include?(mode)
      @abuse_mode = mode
    end

    def validate_abuse!
      %i[abuse_source_request_limit abuse_source_failure_threshold abuse_pair_challenge_threshold abuse_pair_cooldown_threshold abuse_account_failure_threshold abuse_spray_threshold abuse_account_request_limit abuse_public_source_challenge_threshold].each do |name|
        value = public_send(name)
        raise ArgumentError, "Authify #{name} must be a positive integer" unless value.is_a?(Integer) && value.positive?
      end
      raise ArgumentError, "Authify cooldown threshold must be at least the challenge threshold" if abuse_pair_cooldown_threshold < abuse_pair_challenge_threshold
      raise ArgumentError, "Authify abuse durations must be positive" unless abuse_window.to_f.positive? && abuse_device_lifetime.to_f.positive?
      true
    end

    def user_class = user_class_name.constantize
    def session_class = session_class_name.constantize
    def mailer_class = mailer_class_name.constantize

    def email_footer
      email_footer_text.presence || "This message was sent by #{app_name}."
    end
  end
end
