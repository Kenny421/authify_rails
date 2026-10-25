# frozen_string_literal: true
require "net/http"
require "json"

module Authify
  class TurnstileVerifier
    ENDPOINT = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

    def initialize(secret:, hostnames:, http: Net::HTTP)
      @http = http
      @secret = secret
      @hostnames = Array(hostnames).map { |host| host.to_s.strip.downcase }.reject(&:empty?)
    end

    def configured?
      @secret.present? && @hostnames.any?
    end

    def call(token:, request:, action:)
      host = request.host.to_s.downcase
      return false if @secret.blank? || token.blank? || token.bytesize > 2048 || !@hostnames.include?(host)
      message = Net::HTTP::Post.new(ENDPOINT)
      message.set_form_data(secret: @secret, response: token, remoteip: request.remote_ip)
      response = @http.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 2, read_timeout: 2, write_timeout: 2) { |http| http.request(message) }
      return false unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data.is_a?(Hash) && data["success"] == true && data["hostname"].to_s.downcase == host && data["action"] == action
    rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, IOError, Net::ProtocolError, OpenSSL::SSL::SSLError
      false
    end
  end
end
