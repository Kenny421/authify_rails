# frozen_string_literal: true

require "openssl"
require "securerandom"

module Authify
  module Token
    module_function

    def generate(bytes: 32)
      raw = SecureRandom.urlsafe_base64(bytes)
      [raw, digest(raw)]
    end

    def digest(raw)
      OpenSSL::Digest::SHA256.hexdigest(raw.to_s)
    end

    def matches?(raw, expected_digest)
      candidate = digest(raw)
      return false if expected_digest.blank? || candidate.bytesize != expected_digest.bytesize

      ActiveSupport::SecurityUtils.secure_compare(candidate, expected_digest)
    end
  end
end
