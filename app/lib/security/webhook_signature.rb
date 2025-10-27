# app/lib/security/webhook_signature.rb
# frozen_string_literal: true

require "openssl"
require "active_support/security_utils"
require "time"

module Security
  module WebhookSignature
    module_function

    # Returns [ok, error_message_or_nil]
    def verify!(request, secret:, max_skew_seconds: 300)
      return [true, nil] if secret.to_s.empty? # disabled

      ts  = request.get_header("HTTP_X_SELLIOLY_TIMESTAMP").to_s
      sig = request.get_header("HTTP_X_SELLIOLY_SIGNATURE").to_s

      return [false, "Missing timestamp/signature"] if ts.empty? || sig.empty?

      begin
        t = Time.iso8601(ts)
      rescue ArgumentError
        return [false, "Invalid timestamp"]
      end

      if (Time.now.utc - t).abs > max_skew_seconds
        return [false, "Timestamp out of allowed skew"]
      end

      raw = request.raw_post.to_s
      base = "#{ts}\n#{raw}"
      mac  = OpenSSL::HMAC.hexdigest("sha256", secret, base)
      expected = "sha256=#{mac}"

      ok = ActiveSupport::SecurityUtils.secure_compare(expected, sig)
      ok ? [true, nil] : [false, "Invalid signature"]
    end
  end
end
