# app/lib/infra/idempotency_store.rb
# frozen_string_literal: true

require "redis"

module Infra
  class IdempotencyStore
    KEY_PREFIX = "idemp:event:".freeze

    def initialize(url: ENV["REDIS_URL"] || ENV["REDIS_CABLE_URL"], ttl_seconds: 86_400)
      @redis = ::Redis.new(url: url)
      @ttl   = ttl_seconds.to_i
    end

    # Returns true if key was newly stored (i.e., not seen before), false if duplicate.
    def put_once(key)
      k = KEY_PREFIX + key.to_s
      # SET key value NX EX ttl  => set if not exists
      !!@redis.set(k, "1", nx: true, ex: @ttl)
    end
  end
end
