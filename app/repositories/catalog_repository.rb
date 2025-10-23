# frozen_string_literal: true

require "json"

# Read model that fetches and caches catalog data.
# - Uses versioned keys via Cache::Keyspace
# - Negative caches misses for short TTLs
# - Returns parsed JSON hashes or nil (compatible with current helpers)
class CatalogRepository
  def initialize(api: Http::ApiClient.new, cache: Cache::RedisStore.new)
    @api = api
    @cache = cache
  end

  # -------------------- Public API --------------------
  def get_product(handle:, shop_id:, domain:)
    return nil if blank?(handle)
    key = Cache::Keyspace.catalog(shop_id: shop_id, domain: domain, type: :product, id: handle)
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.product, negative_ttl: CATALOG_TTL.negative) do
      res = @api.product_by_handle(handle: handle, shop_id: shop_id, domain: domain)
      res.ok? ? res.json : nil
    end
    tag(:product, hit, shop_id, domain, handle)
    data
  end

  def get_collection(handle:, shop_id:, domain:)
    return nil if blank?(handle)
    key = Cache::Keyspace.catalog(shop_id: shop_id, domain: domain, type: :collection, id: handle)
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.collection, negative_ttl: CATALOG_TTL.negative) do
      res = @api.collection_by_handle(handle: handle, shop_id: shop_id, domain: domain)
      res.ok? ? res.json : nil
    end
    tag(:collection, hit, shop_id, domain, handle)
    data
  end

  def get_menu(handle:, shop_id:, domain:)
    return nil if blank?(handle)
    key = Cache::Keyspace.catalog(shop_id: shop_id, domain: domain, type: :menu, id: handle)
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.menu, negative_ttl: CATALOG_TTL.negative) do
      res = @api.menu_by_handle(handle: handle, shop_id: shop_id, domain: domain)
      res.ok? ? res.json : nil
    end
    tag(:menu, hit, shop_id, domain, handle)
    data
  end

  def get_metadata(shop_id:, domain:)
    key = Cache::Keyspace.catalog(shop_id: shop_id, domain: domain, type: :metadata, id: "store")
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.metadata, negative_ttl: CATALOG_TTL.negative) do
      res = @api.metadata(shop_id: shop_id, domain: domain)
      res.ok? ? res.json : nil
    end
    tag(:metadata, hit, shop_id, domain, "store")
    data
  end

  def get_shop_info(shop_id:)
    # For shop_info we don't have a domain key in your current flow; we scope to shop only.
    key = "v:#{CatalogVersion.current}:shop:#{shop_id}:info"
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.shop_info, negative_ttl: CATALOG_TTL.negative) do
      res = @api.shop_info(shop_id: shop_id)
      res.ok? ? res.json : nil
    end
    tag(:shop_info, hit, shop_id, nil, "info")
    data
  end

  def get_similar_products(handle:, shop_id:, domain:)
    return [] if blank?(handle)
    # Not strictly part of core catalog, but useful for the product page
    key = Cache::Keyspace.catalog(shop_id: shop_id, domain: domain, type: :similar_products, id: handle)
    hit, data = @cache.fetch_json(key: key, ttl: CATALOG_TTL.product, negative_ttl: CATALOG_TTL.negative) do
      res = @api.similar_products_by_handle(handle: handle, shop_id: shop_id, domain: domain)
      res.ok? ? res.json : nil
    end
    tag(:similar_products, hit, shop_id, domain, handle)
    data || []
  end

  # -------------------- Internals --------------------
  private

  def blank?(v)
    v.nil? || (v.respond_to?(:empty?) && v.empty?)
  end

  def tag(type, hit, shop_id, domain, id)
    # Lightweight structured log for observability; safe for now
    Rails.logger.info({
      at: "catalog_repo",
      type: type,
      hit: hit,
      shop_id: shop_id,
      domain: domain,
      id: id,
      version: CatalogVersion.current
    }.to_json)
  rescue StandardError
    # no-op
  end
end
