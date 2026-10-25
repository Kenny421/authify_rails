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
                  :new_sign_in_notifications, :password_change_notifications

    def initialize
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

    def user_class = user_class_name.constantize
    def session_class = session_class_name.constantize
    def mailer_class = mailer_class_name.constantize

    def email_footer
      email_footer_text.presence || "This message was sent by #{app_name}."
    end
  end
end
