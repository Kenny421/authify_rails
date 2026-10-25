# frozen_string_literal: true

require "net/http"
require "openssl"

module Authify
  class PasswordBreachChecker
    ENDPOINT = URI("https://api.pwnedpasswords.com/range/")

    Result = Data.define(:breached, :count, :available)

    def initialize(password, timeout: Authify.configuration.pwned_timeout)
      @password = password.to_s
      @timeout = timeout.to_f
    end

    def call
      sha1 = OpenSSL::Digest::SHA1.hexdigest(@password).upcase
      prefix, suffix = sha1[0, 5], sha1[5..]
      uri = URI.join(ENDPOINT.to_s, prefix)
      request = Net::HTTP::Get.new(uri)
      request["Add-Padding"] = "true"
      request["User-Agent"] = "AuthifyRails/#{Authify::VERSION}"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(request)
      end
      return Result.new(false, 0, false) unless response.is_a?(Net::HTTPSuccess)

      line = response.body.each_line.find { |entry| entry.start_with?("#{suffix}:") }
      count = line ? line.split(":", 2).last.to_i : 0
      Result.new(count.positive?, count, true)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError
      Result.new(false, 0, false)
    end
  end
end
