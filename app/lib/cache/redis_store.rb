# frozen_string_literal: true

require "redis"
require "json"

# Thin wrapper for JSON fetch/write with negative caching.
# Uses the existing REDIS_CABLE_URL if REDIS_URL is absent to avoid breaking
# current deployments.
module Cache
  class RedisStore
    NULL = "NULL".freeze

    def initialize(url: ENV["REDIS_URL"] || ENV["REDIS_CABLE_URL"])
      @redis = ::Redis.new(url: url)
    end

    # Fetches JSON by key. On miss, yields to the block to compute value.
    # - ttl:            seconds for positive items
    # - negative_ttl:   seconds for misses (NULL sentinel)
    # Returns [hit_status, parsed_json_or_nil]
    def fetch_json(key:, ttl:, negative_ttl: 120)
      raw = @redis.get(key)
      if raw
        return [:hit, nil] if raw == NULL
        return [:hit, parse(raw)]
      end

      # Miss
      value = yield if block_given?
      if value.nil?
        @redis.setex(key, negative_ttl, NULL)
        return [:miss, nil]
      else
        payload = value.is_a?(String) ? value : value.to_json
        @redis.setex(key, ttl, payload)
        return [:miss, parse(payload)]
      end
    end

    def write(key:, value:, ttl: nil)
      payload = value.is_a?(String) ? value : value.to_json
      ttl ? @redis.setex(key, ttl, payload) : @redis.set(key, payload)
      true
    end

    def delete(key)
      @redis.del(key)
    end

    private

    def parse(str)
      JSON.parse(str)
    rescue JSON::ParserError
      nil
    end
  end
end
