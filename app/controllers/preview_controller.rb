# app/controllers/preview_controller.rb
# frozen_string_literal: true

class PreviewController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :enforce_preview_token
  before_action :set_cors_headers

  # OPTIONS preflight
  def preflight
    head :ok
  end

  # Generic preview (already exists):
  # GET /preview/:shop_id/:template_id?page=index.json&product=handle
  def show
    render_preview(page: params[:page].presence || 'index.json')
  end

  # ---------- NEW: Builder Preview endpoints ----------

  # GET /preview/:shop_id/:template_id/builder
  # Params:
  #   page=product|collection|cart|checkout|index (shorthands allowed)
  #   product=<handle> (for product preview)
  #   collection=<handle> (for collection preview)
  #   knobs[...] any editor-provided settings overrides (optional)
  def builder
    page = normalize_page(params[:page]) # e.g. "product" -> "product.json"
    render_preview(page: page, builder: true)
  end

  # Legacy aliases used by the editor (kept for convenience)
  # GET /product-preview, /collection-preview, /cart-preview, /checkout-preview
  def legacy_builder_product   ; render_preview(page: 'product.json',   builder: true) ; end
  def legacy_builder_collection; render_preview(page: 'collection.json', builder: true) ; end
  def legacy_builder_cart      ; render_preview(page: 'cart.json',       builder: true) ; end
  def legacy_builder_checkout  ; render_preview(page: 'checkout.json',   builder: true) ; end

  # ---------- NEW: Screenshot endpoint ----------
  # GET /preview/:shop_id/:template_id/screenshot?page=index|product|collection
  # Optional:
  #   product=<handle> / collection=<handle>
  #   delay_ms= (wait before capture), wait_for='#selector' (stability hook)
  def screenshot
    page = normalize_page(params[:page])
    render_preview(page: page, screenshot: true)
  end

  private

  def render_preview(page:, builder: false, screenshot: false)
    shop_id     = params[:shop_id].to_i
    template_id = params[:template_id].to_i

    ctx, failure = Shops::ShopContext.new.from_preview(shop_id: shop_id, template_id: template_id, cookies: cookies)
    return not_found_for_preview(failure&.message || 'Shop not found') unless ctx

    base_args = ctx.base_args.merge(
      'domain'        => nil,               # host-agnostic in preview
      'preview'       => true,              # consumed by tags/snippets if needed
      'builder'       => builder,
      'screenshot'    => screenshot,
      'request'       => { 'params' => request.query_parameters },
      'current_url'   => request.original_url
    )

    # Allow the editor to override section settings live via knobs (optional)
    # e.g. knobs[hero_title]=New title
    if params[:knobs].is_a?(ActionController::Parameters)
      base_args['knobs'] = params[:knobs].to_unsafe_h
    end

    extra_ctx = build_extra_ctx_for(page: page, base_args: base_args)

    # For screenshots: disable external pixels/trackers and freeze animations
    if screenshot
      base_args['content_for_header'] = safe_screenshot_header(base_args['content_for_header'])
    end

    result = Pages::PageRenderer.new.render(
      template_name: page,
      base_args: base_args,
      extra_ctx: extra_ctx,
      theme_path: ctx.theme_path,
      preview: true
    )

    apply_preview_headers(result, screenshot: screenshot)
    render html: result.html.html_safe
  rescue => e
    Rails.logger.error({ at: 'preview', error: e.class.name, message: e.message, backtrace: e.backtrace&.first(5) }.to_json)
    apply_preview_headers(nil, screenshot: screenshot)
    render html: "<!-- preview error: #{ERB::Util.h(e.message)} -->".html_safe, status: :ok
  end

  def build_extra_ctx_for(page:, base_args:)
    repo = CatalogRepository.new
    case page
    when 'product.json'
      return {} unless params[:product].present?
      raw = repo.get_product(handle: params[:product], shop_id: base_args['shop_id'], domain: base_args['domain'])
      return {} unless raw
      { 'product' => ProductPresenter.call(product: raw, params: params, currency: base_args['currency']) }
    when 'collection.json'
      return {} unless params[:collection].present?
      coll = repo.get_collection(handle: params[:collection], shop_id: base_args['shop_id'], domain: base_args['domain'])
      coll ? { 'collection' => coll } : {}
    else
      {}
    end
  end

  def normalize_page(v)
    key = v.to_s.downcase
    case key
    when 'product'    then 'product.json'
    when 'collection' then 'collection.json'
    when 'cart'       then 'cart.json'
    when 'checkout'   then 'checkout.json'
    when 'index', ''  then 'index.json'
    else
      key.end_with?('.json') ? key : "#{key}.json"
    end
  end

  def safe_screenshot_header(existing)
    # Remove pixels/trackers and freeze animations for deterministic screenshots
    css = <<~CSS
      <style>
        * { animation: none !important; transition: none !important; }
        [data-random], .carousel, .marquee { animation: none !important; }
      </style>
    CSS
    (existing.to_s.gsub(/<!--\\s*pixel.*?-->.*?$/m, '') + "\n" + css).strip
  end

  def apply_preview_headers(result = nil, screenshot: false)
    headers['Cache-Control'] = 'no-store'
    headers['X-Robots-Tag']  = 'noindex, nofollow'
    headers['ETag']          = result&.headers&.fetch('ETag', nil) if result
    # Optional stability hints for headless capturer
    headers['X-Preview-Wait-For'] = params[:wait_for].to_s if screenshot && params[:wait_for].present?
    headers['X-Preview-Delay']    = params[:delay_ms].to_s if screenshot && params[:delay_ms].present?
  end

  # --- token / CORS helpers (already present in your PR #7) ---

  def enforce_preview_token
    token = ENV['PREVIEW_TOKEN'].to_s
    return true if token.empty?
    provided = params[:token].to_s
    if ActiveSupport::SecurityUtils.secure_compare(provided, token)
      true
    else
      apply_preview_headers
      render plain: 'Unauthorized preview', status: :unauthorized and return
    end
  end

  def allowed_origins
    ENV.fetch('PREVIEW_ALLOWED_ORIGINS', '').split(',').map(&:strip).reject(&:empty?)
  end

  def set_cors_headers
    origins = allowed_origins
    return if origins.empty?
    request_origin = request.headers['Origin']
    if request_origin && origins.include?(request_origin)
      headers['Access-Control-Allow-Origin']      = request_origin
      headers['Vary']                             = 'Origin'
      headers['Access-Control-Allow-Methods']     = 'GET, OPTIONS'
      headers['Access-Control-Allow-Headers']     = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
      headers['Access-Control-Allow-Credentials'] = 'true'
    end
  end

  def not_found_for_preview(msg)
    apply_preview_headers
    render html: "<!-- preview not found: #{ERB::Util.h(msg)} -->".html_safe, status: :ok
  end
end
