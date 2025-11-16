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
      store = @domain_cache.fetch(domain) { Shop.where(app_domain: domain).first }
      return [nil, Failure.new(type: :not_found, message: "Store not found for #{domain}")] unless store

      build_context_from_store(store: store, domain: domain, cookies: cookies)
    end

    # returns without building context
    def check_store(host:)
      domain, failure = resolve_domain(host)
      return nil if failure

      # 2) Store lookup (cached, short TTL)
      store = @domain_cache.fetch(domain) { Shop.where(app_domain: domain).first }
      store
    end

    # --- Preview path (param-based) ---
    # Signature provided for future unification with PreviewController.
    # Keeps current behavior intact (no usage yet unless you wire it).
    def from_preview(shop_id:, template_id:, cookies: {})
      store = Shop.new(
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
      shop_id     = store.external_store_id
      template_id = store.active_external_template_id
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

      return nil unless File.exist?(data_path)

      settings_data = safe_parse_json(File.read(data_path))
      # settings_schema is optional & shape-agnostic (Hash or Array or nil)
      settings_schema = File.exist?(schema_path) ? safe_parse_json(File.read(schema_path)) : nil

      return nil unless settings_data.is_a?(Hash)

      current_key = settings_data['current']
      presets_hash = settings_data.dig('presets', current_key)
      return nil unless presets_hash.is_a?(Hash)

      presets = {}

      presets_hash.each do |section_id, section_data|
        # Ensure section_data is a Hash
        next unless section_data.is_a?(Hash)

        # Figure out the section type (required to read per-file schema)
        section_type = section_data['type'].to_s
        section_schema =
          begin
            # Prefer per-section schema file: /schemas/<type>.json
            section_schema_path = File.join(theme_path, 'schemas', "#{section_type}.json")
            if File.file?(section_schema_path)
              safe_parse_json(File.read(section_schema_path)) || {}
            # Fallback: if settings_schema is a Hash keyed by section_id, use it
            elsif settings_schema.is_a?(Hash) && settings_schema.key?(section_id)
              settings_schema[section_id] || {}
            else
              {}
            end
          rescue StandardError
            {}
          end

        # Hydrate settings using the resolved schema
        hydrated = section_data.dup
        hydrated_settings = hydrate_section_settings(
          section_schema['settings'].is_a?(Hash) ? section_schema['settings'] : {},
          section_data['settings'].is_a?(Hash)   ? section_data['settings']   : {},
          shop_id, domain
        )
        hydrated['settings'] = hydrated_settings

        # Optionally hydrate blocks if schema defines block settings
        if section_data['blocks'].is_a?(Hash) && section_data['block_order'].is_a?(Array)
          blocks_out = []
          section_data['block_order'].each do |bid|
            bdata = section_data['blocks'][bid]
            next unless bdata.is_a?(Hash)
            btype = bdata['type'].to_s

            block_schema =
              if section_schema['blocks'].is_a?(Hash)
                section_schema['blocks'][btype]
              else
                nil
              end

            if block_schema.is_a?(Hash)
              bsettings = hydrate_section_settings(
                block_schema['settings'].is_a?(Hash) ? block_schema['settings'] : {},
                bdata['settings'].is_a?(Hash)        ? bdata['settings']        : {},
                shop_id, domain
              )
              blocks_out << bdata.merge('settings' => bsettings)
            else
              blocks_out << bdata
            end
          end
          hydrated['blocks'] = blocks_out
        end

        presets[section_id] = hydrated
      end

      presets
    end

    def hydrate_section_settings(schema_settings, data_settings, shop_id, domain)
      ctx = Theme::HydrationCtx.new(shop_id: shop_id, domain: domain, catalog: @catalog)
      registry = Theme::ElementRegistry.default(@catalog)
      Theme::SchemaHydrator.hydrate_settings(schema_settings, data_settings, ctx: ctx, registry: registry)
    end

    # Add this tiny helper near the bottom of the class (private):
    def safe_parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError, Encoding::UndefinedConversionError
      nil
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
        'shop_id'      => store.external_store_id,
        'template_id'  => store.active_external_template_id,
        'template_path'=> store.template_path,
        'app_domain'   => store.app_domain
      }
    end
  end
end