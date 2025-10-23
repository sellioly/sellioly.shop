# frozen_string_literal: true

# Safe per-request timeouts are enforced in Http::ApiClient. This initializer
# is intentionally conservative to avoid breaking existing global defaults.
# If you want to enforce global timeouts, uncomment below — but keep ApiClient
# responsible for SSL verification and timeouts regardless.

# HTTP.default_options = HTTP.default_options.with(
#   features: { auto_inflate: true },
#   headers: { "User-Agent" => "Sellioly-RubyShop/1" }
# )