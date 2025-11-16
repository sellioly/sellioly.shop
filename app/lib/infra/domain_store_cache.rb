# frozen_string_literal: true

# Tiny cache for domain→store lookup to avoid DNS and DB hit on every request.
# TTL is intentionally short (60s) to keep behavior fresh; adjust via env.
module Infra
  class DomainStoreCache
    TTL = (ENV["DOMAIN_STORE_TTL"] || 60).to_i

    def initialize(redis: Redis.new(url: ENV["REDIS_URL"] || ENV["REDIS_CABLE_URL"]))
      @redis = redis
    end

    def fetch(domain)
      key = cache_key(domain)
      raw = @redis.get(key)
      if raw
        data = JSON.parse(raw) rescue nil
        return OpenStruct.new(data) if data
      end

      store = yield
      return nil unless store

      payload = {
        id: store.id,
        shop_id: store.external_store_id,
        template_id: store.active_external_template_id,
        template_path: store.template_path,
        app_domain: store.app_domain
      }.to_json

      @redis.setex(key, TTL, payload)
      store
    end

    private

    def cache_key(domain)
      "domain_store:#{domain.to_s.downcase}"
    end
  end
end