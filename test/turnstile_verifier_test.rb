require "minitest/autorun"
require_relative "../lib/authify"

class TurnstileVerifierTest < Minitest::Test
  class Transport
    attr_accessor :result
    attr_reader :messages
    def initialize(result)
      @result = result
      @messages = []
    end
    def start(*, **) = yield(self)
    def request(message)
      @messages << message
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.body = @result
      response.instance_variable_set(:@read, true)
      response
    end
  end

  def setup
    @transport = Transport.new({ success: true, hostname: "example.com", action: "authify_sign_in" }.to_json)
    @request = Struct.new(:host, :remote_ip).new("example.com", "198.51.100.1")
    @verifier = Authify::TurnstileVerifier.new(secret: "server-secret", hostnames: ["example.com"], http: @transport)
  end

  def test_requires_success_hostname_and_action
    assert @verifier.call(token: "single-use-token", request: @request, action: "authify_sign_in")
    refute @verifier.call(token: "single-use-token", request: @request, action: "authify_registration")
    @transport.result = { success: true, hostname: "other.example", action: "authify_sign_in" }.to_json
    refute @verifier.call(token: "single-use-token", request: @request, action: "authify_sign_in")
  end

  def test_rejects_replayed_expired_or_malformed_provider_responses
    @transport.result = { success: false, "error-codes": ["timeout-or-duplicate"] }.to_json
    refute @verifier.call(token: "expired", request: @request, action: "authify_sign_in")
    @transport.result = "not-json"
    refute @verifier.call(token: "token", request: @request, action: "authify_sign_in")
  end

  def test_rejects_unknown_host_and_empty_tokens_before_network_call
    @request.host = "untrusted.example"
    refute @verifier.call(token: "token", request: @request, action: "authify_sign_in")
    assert_empty @transport.messages
  end
end
