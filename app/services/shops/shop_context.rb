# frozen_string_literal: true

require "resolv"

module Shops
  # Orchestrates host→store resolution and builds the base theme context.
  # Mirrors existing behavior from ApplicationController#initialize_shop & check_store.
  class ShopContext
    Context = Struct.new(
      :domain, :shop_id, :template_id, :theme_path,
      :store, :base_args,
      keyword_init: true
    )

    Failure = Struct.new(:type, :message, keyword_init: true)

    def initialize(
      api: Http::ApiClient.new,
      catalog: CatalogRepository.new,
      domain_cache: Infra::DomainStoreCache.new
    )
      @api = api
      @catalog = catalog
      @domain_cache = domain_cache
    end

    # --- Live storefront path (domain-based) ---
    # Returns [Context, nil] on success; [nil, Failure] on failure.
    def resolve!(host:, cookies: {})
      # 1) Domain resolution (CNAME + verify) → app_domain
      domain, failure = resolve_domain(host)
      return [nil, failure] if failure

      # 2) Store lookup (cached, short TTL)
      store = @domain_cache.fetch(domain) { Store.where(app_domain: domain).first }
      return [nil, Failure.new(type: :not_found, message: "Store not found for #{domain}")] unless store

      build_context_from_store(store: store, domain: domain, cookies: cookies)
    end

    # --- Preview path (param-based) ---
    # Signature provided for future unification with PreviewController.
    # Keeps current behavior intact (no usage yet unless you wire it).
    def from_preview(shop_id:, template_id:, cookies: {})
      store = Store.new(
        shop_id: shop_id,
        template_id: template_id,
        template_path: "/storage/#{shop_id}/#{template_id}",
        app_domain: nil
      )
      # Preview has no domain verification; domain is derived from shop info
      build_context_from_store(store: store, domain: nil, cookies: cookies)
    end

    private

    # --- Domain resolution logic, mirrors check_store ---
    def resolve_domain(host)
      domain = host

      cname = begin
        Resolv::DNS.new.getresource(domain, Resolv::DNS::Resource::IN::CNAME)
      rescue StandardError
        nil
      end

      if cname
        app_domain = cname.name.to_s
        res = @api.verify_domain(domain: domain, app_domain: app_domain)
        return [nil, Failure.new(type: :not_found, message: "Domain verify failed: #{domain} -> #{app_domain}")] unless res.ok?
        domain = app_domain
      else
        unless domain =~ /^[A-Za-z0-9.-]+\.sellioly\.com$/
          return [nil, Failure.new(type: :not_found, message: "Domain format error: #{domain}")]
        end
      end

      [domain, nil]
    end

    def build_context_from_store(store:, domain:, cookies: {})
      shop_id     = store.shop_id
      template_id = store.template_id
      theme_path  = File.join(Rails.root.to_s, store.template_path.to_s)

      # 1) Shop info (name, currency, logo, description)
      shop = @catalog.get_shop_info(shop_id: shop_id)
      return [nil, Failure.new(type: :api_error, message: "Shop info unavailable")] unless shop

      # 2) Base args (mirrors your initialize_shop)
      base_args = {
        'shop_id'          => shop_id,
        'template_id'      => template_id,
        'page_title'       => "HOME - #{shop['shop_name']}",
        'shop_name'        => shop['shop_name'],
        'shop_description' => shop['shop_description'],
        'currency'         => shop['currency'],
        'logo'             => shop['shop_logo_default']
      }

      # 3) Cart snapshot
      if cookies[:cart_id].present?
        cart = Cart.find_by(cart_id: cookies[:cart_id])
        if cart
          base_args['cart'] = cart.as_json
        else
          new_cart = Cart.create!(cart_id: cookies[:cart_id], items: [], subtotal: 0)
          base_args['cart'] = new_cart.as_json
        end
      end

      # 4) Presets
      presets = read_and_hydrate_presets(theme_path, shop_id: shop_id, domain: domain)
      base_args['presets'] = presets if presets

      # 5) Metadata & pixels
      if domain
        metadata = @catalog.get_metadata(shop_id: shop_id, domain: domain)
        base_args['metadata'] = metadata if metadata
        base_args['content_for_header'] = metadata ? build_pixels(metadata) : ""
      else
        base_args['content_for_header'] = ""
      end

      ctx = Context.new(
        domain: domain,
        shop_id: shop_id,
        template_id: template_id,
        theme_path: theme_path,
        store: normalized_store(store),
        base_args: base_args
      )

      [ctx, nil]
    end

    def read_and_hydrate_presets(theme_path, shop_id:, domain:)
      data_path   = File.join(theme_path, 'config', 'settings_data.json')
      schema_path = File.join(theme_path, 'config', 'settings_schema.json')
      return nil unless File.exist?(data_path) && File.exist?(schema_path)

      begin
        settings_data   = JSON.parse(File.read(data_path))
        settings_schema = JSON.parse(File.read(schema_path))
      rescue JSON::ParserError, Encoding::UndefinedConversionError
        return nil
      end

      current = settings_data.dig('presets', settings_data['current'])
      return nil unless current.is_a?(Hash)

      presets = {}
      current.each do |section_id, section_data|
        schema_data = settings_schema[section_id]
        presets[section_id] = section_data.dup
        next unless schema_data
        presets[section_id]['settings'] = hydrate_section_settings(schema_data['settings'], section_data['settings'], shop_id, domain)
      end

      presets
    end

    def hydrate_section_settings(schema_settings, data_settings, shop_id, domain)
      return {} unless schema_settings.is_a?(Hash) && data_settings.is_a?(Hash)

      hydrated = data_settings.dup
      hydrated.each do |key, value|
        next unless schema_settings[key]
        value = schema_settings[key]['default'] if value.nil?

        case schema_settings[key]['element']
        when 'menu'
          if (menu = @catalog.get_menu(handle: value, shop_id: shop_id, domain: domain))
            hydrated[key] = menu
          end
        when 'product-picker'
          if (prod = @catalog.get_product(handle: value, shop_id: shop_id, domain: domain))
            hydrated[key] = prod
          end
        when 'products-picker'
          handles = Array(value)
          products = handles.filter_map { |h| @catalog.get_product(handle: h, shop_id: shop_id, domain: domain) }
          hydrated[key] = products
        when 'collection-picker'
          if (coll = @catalog.get_collection(handle: value, shop_id: shop_id, domain: domain))
            hydrated[key] = coll
          end
        else
          # passthrough for primitive values
        end
      end

      hydrated
    end

    def build_pixels(metadata)
      header = ""
      pixels = metadata['pixels'] || {}
      pixels.each_value do |list|
        Array(list).each do |pixel|
          header << pixel['pixel_code'].to_s << "" if pixel.is_a?(Hash) && pixel.key?('pixel_code')
        end
      end
      header
    end

    def normalized_store(store)
      {
        'id'           => store.id,
        'shop_id'      => store.shop_id,
        'template_id'  => store.template_id,
        'template_path'=> store.template_path,
        'app_domain'   => store.app_domain
      }
    end
  end
end