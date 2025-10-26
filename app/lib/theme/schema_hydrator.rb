# app/lib/theme/schema_hydrator.rb
# frozen_string_literal: true

module Theme
  # Context passed to resolvers
  HydrationCtx = Struct.new(:shop_id, :domain, :catalog, keyword_init: true)

  # Registry owns a Hash<String, Proc>
  class ElementRegistry
    def initialize(map)  # { 'menu' => ->(value, ctx, cfg) { ... } , ... }
      @map = map.freeze
    end

    def resolve(element, value, ctx, cfg)
      handler = @map[element] || @map['__primitive__']
      handler.call(value, ctx, cfg)
    end

    # Default registry wired to CatalogRepository
    def self.default(catalog)
      new({
        # pickers
        'menu' => ->(value, ctx, _cfg) {
          value && (ctx.catalog.get_menu(handle: value, shop_id: ctx.shop_id, domain: ctx.domain) || value)
        },
        'product-picker' => ->(value, ctx, _cfg) {
          value && (ctx.catalog.get_product(handle: value, shop_id: ctx.shop_id, domain: ctx.domain) || value)
        },
        'products-picker' => ->(value, ctx, _cfg) {
          Array(value).compact.filter_map { |h| ctx.catalog.get_product(handle: h, shop_id: ctx.shop_id, domain: ctx.domain) }
        },
        'collection-picker' => ->(value, ctx, _cfg) {
          value && (ctx.catalog.get_collection(handle: value, shop_id: ctx.shop_id, domain: ctx.domain) || value)
        },

        # example for future elements:
        # 'blog-picker' => ->(value, ctx, _cfg) { ... },

        # fallback for primitives / unknown elements
        '__primitive__' => ->(value, _ctx, cfg) {
          value.nil? ? cfg['default'] : value
        }
      })
    end
  end

  module SchemaHydrator
    module_function

    # Applies defaults + resolves pickers using registry (single source of truth).
    # - schema_settings: Hash of setting_key => config (must include 'element' and optional 'default')
    # - data_settings:   Hash of setting_key => value (may omit keys or set null)
    # - ctx:             Theme::HydrationCtx (shop_id, domain, catalog)
    # - registry:        Theme::ElementRegistry
    def hydrate_settings(schema_settings, data_settings, ctx:, registry:)
      hydrated = (data_settings || {}).dup

      schema_settings.each do |key, cfg|
        next unless cfg.is_a?(Hash)
        element = cfg['element'].to_s

        # pick value: explicit value wins; otherwise default
        value = hydrated.key?(key) ? hydrated[key] : cfg['default']
        value = cfg['default'] if value.nil?

        hydrated[key] = registry.resolve(element, value, ctx, cfg)
        # Ensure arrays default to [] when resolver returns nil for list-like elements
        if element == 'products-picker' && hydrated[key].nil?
          hydrated[key] = []
        end
      end

      hydrated
    end
  end
end
