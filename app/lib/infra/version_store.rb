# app/lib/infra/version_store.rb
# frozen_string_literal: true

module Infra
  class VersionStore
    def initialize(redis: Redis.new(url: ENV["REDIS_URL"] || ENV["REDIS_CABLE_URL"]))
      @redis = redis
    end

    # ---- key builders (no TTL for counters) ----
    def k_shop_catalog(shop_id)            = "v:shop:#{shop_id}:catalog"
    def k_collection(shop_id, handle)      = "v:shop:#{shop_id}:collection:#{handle}"
    def k_menu(shop_id, handle)            = "v:shop:#{shop_id}:menu:#{handle}"
    def k_product(shop_id, handle)         = "v:shop:#{shop_id}:product:#{handle}"
    def k_metadata(shop_id)                = "v:shop:#{shop_id}:metadata"

    # ---- bumps ----
    def bump_shop_catalog(shop_id)         = @redis.incr(k_shop_catalog(shop_id))
    def bump_collection(shop_id, handle)   = @redis.incr(k_collection(shop_id, handle))
    def bump_menu(shop_id, handle)         = @redis.incr(k_menu(shop_id, handle))
    def bump_product(shop_id, handle)      = @redis.incr(k_product(shop_id, handle))
    def bump_metadata(shop_id)             = @redis.incr(k_metadata(shop_id))

    # ---- reads (return Integer; missing = 0) ----
    def get_shop_catalog(shop_id)          = (@redis.get(k_shop_catalog(shop_id)) || "0").to_i
    def get_collection(shop_id, handle)    = (@redis.get(k_collection(shop_id, handle)) || "0").to_i
    def get_menu(shop_id, handle)          = (@redis.get(k_menu(shop_id, handle)) || "0").to_i
    def get_product(shop_id, handle)       = (@redis.get(k_product(shop_id, handle)) || "0").to_i
    def get_metadata(shop_id)              = (@redis.get(k_metadata(shop_id)) || "0").to_i
  end
end
