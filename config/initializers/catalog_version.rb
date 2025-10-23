# frozen_string_literal: true

# Minimal global version for catalog cache keys. Bump to invalidate quickly
# without scanning Redis. In PR #7 we will add scoped bumps (per product/menu/collection).
module CatalogVersion
  KEY = "catalog_version".freeze

  module_function

  def redis
    @redis ||= Redis.new(url: ENV["REDIS_URL"] || ENV["REDIS_CABLE_URL"]) # keep compat
  end

  def current
    (redis.get(KEY) || "1").to_i
  end

  def bump!
    redis.incr(KEY)
  end
end
