require "minitest/autorun"
require_relative "../lib/authify"

class AbuseProtectionTest < Minitest::Test
  class Store
    attr_accessor :values, :requests
    attr_reader :writes
    def initialize
      @values = { pair_failures: 0, source_failures: 0, account_failures: 0, distinct_accounts: 0, account_requests: 0, last_failure_at: Time.current }
      @requests = 0
      @writes = []
    end
    def bump!(**values) = @writes << values
    def snapshot(**) = values
    def source_requests(**) = requests
    def trusted?(*, **) = @trusted
    def trust!(*, **) = @trusted = true
    def forget_devices!(*) = @trusted = false
  end

  def setup
    Authify.reset_configuration!
    @store = Store.new
    @time = Time.current
    @previous_application = Rails.application
    app = Object.new
    key = ActiveSupport::KeyGenerator.new("test-key")
    app.define_singleton_method(:key_generator) { key }
    Rails.application = app
  end

  def teardown
    Rails.application = @previous_application
    Authify.reset_configuration!
  end

  def risk(**options)
    Authify::AbuseProtection.new(source: "198.51.100.1", account: "member@example.com", store: @store, clock: -> { @time }, **options)
  end

  def test_normal_typographical_failures_remain_allowed
    @store.values[:pair_failures] = 2
    assert_equal :allow, risk.check!.action
  end

  def test_detects_spraying_and_distributed_account_attacks
    @store.values[:distinct_accounts] = 10
    assert_includes risk.check!.reasons, "password_spraying"
    @store.values[:distinct_accounts] = 0
    @store.values[:account_failures] = 10
    assert_includes risk.check!.reasons, "distributed_account_failures"
  end

  def test_pair_cooldown_is_bounded_and_does_not_extend_on_blocked_requests
    @store.values.merge!(pair_failures: 10, last_failure_at: @time)
    assert_equal :cooldown, risk.check!.action
    @time += 31
    assert_equal :challenge, risk.check!.action
    @store.values.merge!(pair_failures: 1000, last_failure_at: @time)
    assert_operator risk.check!.retry_after, :<=, 300
  end

  def test_source_budget_is_checked_before_allocating_account_buckets
    @store.requests = 301
    assert_equal :cooldown, risk.check!.action
    assert_equal ["source_request"], @store.writes.map { |entry| entry[:kind] }
  end

  def test_trusted_browser_still_needs_credentials_and_never_bypasses_pair_restrictions
    @store.values.merge!(account_failures: 30, source_failures: 40, distinct_accounts: 20)
    assert_equal :challenge, risk(device: "browser").check!.action
    risk.succeeded!(device: "browser")
    assert_equal :allow, risk(device: "browser").check!.action
    @store.values.merge!(pair_failures: 10, last_failure_at: @time)
    assert_equal :cooldown, risk(device: "browser").check!.action
  end

  def test_counter_identifiers_are_hashed_and_tenant_scoped
    first = risk(tenant: 10)
    second = risk(tenant: 20)
    refute_equal first.account, second.account
    first.failed!
    entry = @store.writes.last
    refute_includes entry.to_s, "member@example.com"
    refute_includes entry.to_s, "198.51.100.1"
    assert_equal 64, entry[:account].length
  end

  def test_off_mode_does_not_record_requests
    Authify.configuration.abuse_mode = :off
    assert_equal :allow, risk.check!.action
    assert_empty @store.writes
  end
  def test_invalid_configuration_cannot_silently_disable_enforcement
    assert_raises(ArgumentError) { Authify.configuration.abuse_mode = :enfroce }
    Authify.configuration.abuse_pair_cooldown_threshold = 0
    assert_raises(ArgumentError) { risk.check! }
  end

end
