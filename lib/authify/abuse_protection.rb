# frozen_string_literal: true
require "openssl"

module Authify
  # Rule-based risk signals. All identities are keyed hashes; no passwords, raw
  # email addresses, IP addresses or device tokens are persisted in the counters.
  class AbuseProtection
    Decision = Struct.new(:action, :reasons, :retry_after, keyword_init: true)
    attr_reader :source, :account, :action

    def initialize(source:, account:, tenant: nil, device: nil, action: :sign_in, store: nil, clock: -> { Time.current })
      @clock = clock
      @store = store || AuthifyAbuseBucket
      @source = digest("source", source)
      @account = digest("account", [tenant, account.to_s.strip.downcase])
      @device = device.present? ? digest("device", [@account, device]) : nil
      @action = action.to_s
    end

    def check!
      config = Authify.configuration
      return decision(:allow) if config.abuse_mode.to_sym == :off
      config.validate_abuse!
      now = @clock.call
      window = config.abuse_window
      @store.bump!(kind: "source_request", action: action, source: source, account: source, now: now, lifetime: window)
      requests = @store.source_requests(action: action, source: source, now: now, window: window)
      if requests > config.abuse_source_request_limit
        return decision(:cooldown, ["source_request_budget"], retry_after: 60 - now.to_i % 60)
      end
      @store.bump!(kind: "request", action: action, source: source, account: account, now: now, lifetime: window)
      stats = @store.snapshot(action: action, source: source, account: account, now: now, window: window)
      trusted = @device && @store.trusted?(@device, now: now)
      reasons = []
      if stats[:pair_failures] >= config.abuse_pair_cooldown_threshold
        delay = [30 * (2 ** [stats[:pair_failures] / config.abuse_pair_cooldown_threshold - 1, 4].min), 300].min
        remaining = (stats[:last_failure_at] + delay - now).ceil
        return decision(:cooldown, ["repeated_pair_failures"], retry_after: remaining) if remaining.positive?
      end
      unless trusted && stats[:pair_failures] < config.abuse_pair_challenge_threshold
        reasons << "source_failures" if stats[:source_failures] >= config.abuse_source_failure_threshold
        reasons << "password_spraying" if stats[:distinct_accounts] >= config.abuse_spray_threshold
      end
      reasons << "repeated_pair_failures" if stats[:pair_failures] >= config.abuse_pair_challenge_threshold
      reasons << "distributed_account_failures" if !trusted && stats[:account_failures] >= config.abuse_account_failure_threshold
      if action != "sign_in" && requests > config.abuse_public_source_challenge_threshold
        reasons << "public_source_requests"
      end
      if action != "sign_in" && stats[:account_requests] > config.abuse_account_request_limit
        reasons << "account_request_budget"
      end
      decision(reasons.empty? ? :allow : :challenge, reasons)
    rescue ActiveRecord::ActiveRecordError => error
      ActiveSupport::Notifications.instrument("authify.abuse_store_error", error_class: error.class.name, mode: config.abuse_mode)
      decision(:unavailable, ["counter_store_unavailable"], retry_after: 30)
    end

    def failed!
      return if Authify.configuration.abuse_mode.to_sym == :off
      @store.bump!(kind: "failure", action: action, source: source, account: account, now: @clock.call, lifetime: Authify.configuration.abuse_window)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
    end

    def forget_devices!
      @store.forget_devices!(account)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
    end

    def factor_challenge_allowed?
      @store.consume_budget!(kind: "factor_issuance", key: account, now: @clock.call, limit: 20, window: 5.minutes)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
      false
    end

    def sensitive_attempt!
      @store.consume_budget!(kind: "reauthenticate", key: account, now: @clock.call, limit: 10, window: 5.minutes)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
      false
    end

    def factor_attempt!(challenge:)
      now = @clock.call
      key = digest("factor", [account, challenge])
      @store.consume_budget!(kind: "factor_account", key: account, now: now, limit: 10, window: 5.minutes) &&
        @store.consume_budget!(kind: "factor_challenge", key: key, now: now, limit: 5, window: 5.minutes)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
      false
    end

    def succeeded!(device:)
      return if Authify.configuration.abuse_mode.to_sym == :off
      key = digest("device", [account, device])
      @store.trust!(key, account: account, expires_at: @clock.call + Authify.configuration.abuse_device_lifetime)
    rescue ActiveRecord::ActiveRecordError => error
      store_error(error)
    end

    private

    def store_error(error)
      ActiveSupport::Notifications.instrument("authify.abuse_store_error", error_class: error.class.name, mode: Authify.configuration.abuse_mode)
      nil
    end

    def digest(purpose, value)
      key = Rails.application.key_generator.generate_key("authify/abuse/v1", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, [purpose, value].to_json)
    end

    def decision(action, reasons = [], retry_after: 0)
      result = Decision.new(action: action, reasons: reasons, retry_after: retry_after)
      ActiveSupport::Notifications.instrument("authify.abuse_decision", action: self.action, decision: action, reasons: reasons, mode: Authify.configuration.abuse_mode, source_digest: source, account_digest: account)
      result
    end
  end
end
