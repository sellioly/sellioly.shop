# frozen_string_literal: true

module Pages
  # Orchestrates JSON→sections→layout rendering for a page.
  class PageRenderer
    Result = Struct.new(:html, :headers, keyword_init: true)

    def initialize(catalog: CatalogRepository.new)
      @catalog = catalog
    end

    # Render a page by template JSON filename (e.g., "index.json", "product.json").
    # - base_args: the base Liquid assigns from ShopContext
    # - extra_ctx: extra assigns for the page (e.g., product, collection)
    # - theme_path: absolute path to theme root
    # - preview: boolean (controls developer hints vs. silent failures)
    def render(template_name:, base_args:, extra_ctx: {}, theme_path:, preview: false)
      store     = Theme::ThemeStore.new(root: theme_path)
      compiler  = Theme::TemplateCompiler.new
      renderer  = Theme::LiquidRenderer.new

      assigns   = (base_args || {}).merge(extra_ctx || {})
      registers = {
        'theme_store' => store,
        'compiler'    => compiler,
        'renderer'    => renderer,
        'preview'     => !!preview,
        'include_depth' => 0,
      }

      # 1) Read template JSON
      page = store.read_template_json(template_name)
      raise_missing!(preview, "templates/#{template_name}") unless page

      layout_name = (page['layout'] || 'theme').to_s

      # 2) Build content_for_layout by rendering ordered sections
      content_for_layout = String.new
      sections_block     = Array(page['order'])
      sections_def       = (page['sections'] || {})

      sections_block.each do |section_id|
        section_data = sections_def[section_id]
        next unless section_data

        section_type = section_data['type'].to_s
        section_liquid = File.join('sections', "#{section_type}.liquid")
        unless store.exists?(section_liquid)
          content_for_layout << preview_hint(preview, "Missing section: #{section_liquid}")
          next
        end

        # Hydrate section settings/blocks via schema
        schema_json = store.read_schema_json(section_type) || {}
        section_assigns = build_section_assigns(assigns, section_data, schema_json)

        # log assigns for debugging
        Rails.logger.info({ at: 'page_renderer', section: section_id, assigns: section_assigns }.to_json)

        # Render the section via the compiled template
        compiled = compiler.compile(theme_store: store, rel_path: section_liquid)
        content_for_layout << renderer.safe_render(compiled, assigns: section_assigns, theme_store: store, registers: registers)
      end

      # 3) Merge layout_data from layout JSON (optional)
      layout_json = store.read_layout_json(layout_name)
      if layout_json && layout_json['sections'].is_a?(Hash)
        hydrated_layout = hydrate_layout_sections(assigns, layout_json['sections'], store)
        assigns = assigns.merge('layout_data' => hydrated_layout)
      end

      # 4) Render layout
      layout_rel = File.join('layout', "#{layout_name}.liquid")
      raise_missing!(preview, layout_rel) unless store.exists?(layout_rel)

      assigns = assigns.merge('content_for_layout' => content_for_layout)
      compiled_layout = compiler.compile(theme_store: store, rel_path: layout_rel)

      html = renderer.safe_render(compiled_layout, assigns: assigns, theme_store: store, registers: registers)

      # 5) Optional headers (weak ETag based on template + layout file digests)
      etag = weak_etag_for(store, template_name: template_name, layout_rel: layout_rel)
      Result.new(html: html, headers: { 'ETag' => etag, 'Cache-Control' => default_cache_control(preview) })
    end

    private

    # Build assigns for a section render; mirrors PR#3 hydration but scoped to a given section
    def build_section_assigns(base_assigns, section_data, schema_json)
      assigns = base_assigns.dup

      # Section settings
      settings_schema = (schema_json['settings'] || {})
      data_settings   = (section_data['settings'] || {})
      hydrated_settings = hydrate_settings(settings_schema, data_settings, base_assigns)

      # Blocks
      blocks = []
      Array(section_data['block_order']).each do |bid|
        bdata = section_data.dig('blocks', bid)
        next unless bdata
        if (block_schema = safe_block_schema(schema_json, bdata['type']))
          bsettings = hydrate_settings(block_schema['settings'] || {}, bdata['settings'] || {}, base_assigns)
          blocks << bdata.merge('settings' => bsettings)
        else
          blocks << bdata
        end
      end

      assigns.merge('section' => { 'settings' => hydrated_settings, 'blocks' => blocks })
    end

    def hydrate_layout_sections(base_assigns, layout_sections_hash, store)
      result = {}
      layout_sections_hash.each do |sid, sdata|
        schema_json = store.read_schema_json(sdata['type'].to_s) || {}
        settings = hydrate_settings(schema_json['settings'] || {}, sdata['settings'] || {}, base_assigns)
        result[sid] = sdata.merge('settings' => settings)
      end
      result
    end

    # Hydrate schema-driven settings using CatalogRepository for pickers
    def hydrate_settings(schema_settings, data_settings, base_assigns)
      ctx = Theme::HydrationCtx.new(
        shop_id: base_assigns['shop_id'],
        domain:  (base_assigns['domain'] || base_assigns['app_domain']),
        catalog: @catalog
      )
      registry = Theme::ElementRegistry.default(@catalog)
      Theme::SchemaHydrator.hydrate_settings(schema_settings, data_settings, ctx: ctx, registry: registry)
    end

    def safe_block_schema(schema_json, block_type)
      blocks = schema_json['blocks']
      return nil unless blocks.is_a?(Hash)
      blocks[block_type]
    end

    def preview_hint(preview, msg)
      preview ? "<!-- #{msg} -->" : ""
    end

    def raise_missing!(preview, rel)
      if preview
        # In preview we prefer a visible marker; still raise to surface in logs if desired
        raise "Missing theme file: #{rel}"
      else
        raise ActionController::RoutingError, "Missing theme file: #{rel}"
      end
    end

    def weak_etag_for(store, template_name:, layout_rel:)
      tdig = store.file_digest(File.join('templates', template_name))
      ldig = store.file_digest(layout_rel)
      %W[W/\"p#{tdig}-l#{ldig}\"].join
    end

    def default_cache_control(preview)
      preview ? 'no-store' : 'max-age=60, public'
    end
  end
end
