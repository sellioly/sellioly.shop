# frozen_string_literal: true

# Centralized key naming. Keeps compatibility with your current style but
# adds an explicit version token for fast invalidation.
module Cache
  module Keyspace
    module_function

    # Example: v:12:shop:63:domain:foo.sellioly.com:product:my-handle
    def catalog(shop_id:, domain:, type:, id:, version: CatalogVersion.current)
      d = normalize_domain(domain)
      "v:#{version}:shop:#{shop_id}:domain:#{d}:#{type}:#{id}"
    end

    def normalize_domain(domain)
      domain.to_s.downcase
    end
  end
end