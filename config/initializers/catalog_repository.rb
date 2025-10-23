# frozen_string_literal: true

# TTL policy (seconds). Tune per environment if needed.
CatalogTTL = Struct.new(:product, :collection, :menu, :metadata, :shop_info, :negative, keyword_init: true)

CATALOG_TTL = CatalogTTL.new(
  product:   (ENV["TTL_PRODUCT"]   || 600).to_i,  # 10m
  collection:(ENV["TTL_COLLECTION"]|| 600).to_i,  # 10m
  menu:      (ENV["TTL_MENU"]      || 600).to_i,  # 10m
  metadata:  (ENV["TTL_METADATA"]  || 1800).to_i, # 30m
  shop_info: (ENV["TTL_SHOP_INFO"] || 900).to_i,  # 15m
  negative:  (ENV["TTL_NEGATIVE"]  || 120).to_i   # 2m
)