# app/controllers/shop_controller.rb
# frozen_string_literal: true

class ShopController < ApplicationController
  before_action :initialize_shop, except: [:file_assets, :file_font_assets]
  before_action :ensure_cart!    # guarantees @args['cart'] is present (SSR)

  # ---------------- Static assets served from the theme storage ----------------
  # (Kept here; preview routes point to these too.)
  def file_assets
    theme_root = File.join(Rails.root.to_s, 'storage', params[:shop_id].to_s, params[:template_id].to_s)
    path = File.join(theme_root, 'assets', params[:filename].to_s)

    return content_not_found unless File.directory?(theme_root) && File.exist?(path)
    expires_in 24.hours, public: true
    send_file path, disposition: 'inline'
  end

  def file_font_assets
    theme_root = File.join(Rails.root.to_s, 'storage', params[:shop_id].to_s, params[:template_id].to_s)
    path = File.join(theme_root, 'assets', 'fonts', params[:filename].to_s)

    return content_not_found unless File.directory?(theme_root) && File.exist?(path)
    expires_in 24.hours, public: true
    send_file path, disposition: 'inline'
  end

  # --------------------------------- Pages ------------------------------------

  def index
    render_with_renderer('index.json')
  end

  def product
    repo = CatalogRepository.new
    raw  = repo.get_product(handle: params[:product], shop_id: @shop_id, domain: @domain)
    return render_with_renderer('404.json', status: :not_found) unless raw

    product_vm = ProductPresenter.call(
      product:  raw,
      params:   params,
      currency: @args['currency'] # من ShopContext
    )

    # Optional: similar products (keep if you want it)
    similar = repo.get_similar_products(handle: params[:product], shop_id: @shop_id, domain: @domain)

    extra_ctx = {}
    extra_ctx['product']          = product_vm['product']
    extra_ctx['selected_variant'] = product_vm['selected_variant']
    extra_ctx['variant_index']    = product_vm['variant_index']
    extra_ctx['variant_image_map']= product_vm['variant_image_map']
    extra_ctx['urls']             = product_vm['urls']
    extra_ctx['similar_products'] = similar if similar.present?

    render_with_renderer('product.json', extra_ctx: extra_ctx)
  end

  def collection
    repo = CatalogRepository.new

    # 1. Get collection info
    collection = repo.get_collection(handle: params[:collection], shop_id: @shop_id, domain: @domain)
    return render_with_renderer('404.json', status: :not_found) unless collection

    # 2. Get products belonging to that collection (accepts filters)
    filters = request.query_parameters.presence || {}
    products = repo.get_collection_products(
      handle: params[:collection],
      shop_id: @shop_id,
      domain: @domain,
      filters: filters
    )

    # 3. Build context for Liquid
    extra_ctx = {
      'collection' => collection,
      'products'   => products,  # can be nil if empty
      'filters'    => filters    # helpful for your filter bar snippet
    }

    render_with_renderer('collection.json', extra_ctx: extra_ctx)
  end

  def collection_products_json
    repo = CatalogRepository.new

    # Get collection info (for validation)
    collection = repo.get_collection(handle: params[:collection], shop_id: @shop_id, domain: @domain)
    return render json: { error: 'Collection not found' }, status: :not_found unless collection

    # Get products with filters from query params
    filters = request.query_parameters.presence || {}
    products = repo.get_collection_products(
      handle: params[:collection],
      shop_id: @shop_id,
      domain: @domain,
      filters: filters
    )

    # Return JSON response (products data structure from CatalogRepository)
    render json: {
      data: products&.dig('data') || [],
      meta: products&.dig('meta') || {}
    }
  end

  def cart
    cart = @args['cart'] || {}
    # active_checkout_session_id removed - checkout flow changed
    render_with_renderer('cart.json')
  end

  def checkout
    # /checkout?session_id=xxxx
    session_id = params[:session_id].to_s.presence

    extra_ctx = {
      checkout_session: nil
    }

    # Load checkout session data
    if session_id
      repo = CheckoutSessionRepository.new
      checkout_session = repo.show(id: session_id).json
      extra_ctx['checkout_session'] = checkout_session if checkout_session
    end

    # redirect to cart if no session_id or invalid session
    return redirect_to('/cart') unless extra_ctx['checkout_session']

    # check if session is already placed
    if extra_ctx['checkout_session']['status'].to_s == 'completed'
      order_id = extra_ctx['checkout_session']['order_id'].to_s.presence
      return redirect_to("/order-completed/#{order_id}") if order_id
    end

    render_with_renderer('checkout.json', extra_ctx: extra_ctx)
  end

  def our_store
    render_with_renderer('our-store.json')
  end

  def about_us
    render_with_renderer('about-us.json')
  end

  def order_completed
    order_id = params[:order].to_s.presence
    return render_with_renderer('404.json', status: :not_found) unless order_id

    repo = OrderRepository.new

    order_data = repo.show(order_id: order_id).json
    # New API returns order directly (no wrapper)
    order = order_data if order_data

    return render_with_renderer('404.json', status: :not_found) unless order

    extra_ctx = { 'order' => order }
    render_with_renderer('order-done.json', extra_ctx: extra_ctx)
  end

  # Catch-all “page” route: serves a template if present, else 404.
  def page
    template_name = "#{params[:path]}.json"
    theme_store   = Theme::ThemeStore.new(root: @path)
    if theme_store.exists?(File.join('templates', template_name))
      render_with_renderer(template_name)
    else
      render_with_renderer('404.json', status: :not_found)
    end
  end

  def not_found
    render_with_renderer('404.json', status: :not_found)
  end

  private

  # Ensure we have a cart_id cookie and preload @args['cart'] from Laravel (via proxy)
  def ensure_cart!
    cart_repo = CartRepository.new

    cart_id = request.cookies['cart_id'] || cookies['cart_id'] || cookies[:cart_id] || nil

    # GET cart snapshot (idempotent, cheap)
    cart = cart_repo.show(cart_id: cart_id)

    if cart
      cart_id = cart['id']
      cookies[:cart_id] = {
        value: cart_id,
        domain: request.host,
        path: '/',
        same_site: :lax,
        secure: Rails.env.production?,
        expires: 30.days
      }
    end

    # Always inject cart into args for SSR (header badge, mini-cart, etc.)
    @args['cart'] = cart || default_empty_cart(cart_id)
  rescue => e
    Rails.logger.warn({ at: 'ensure_cart', err: e.class.name, msg: e.message }.to_json)
    @args['cart'] ||= default_empty_cart(cart_id || request.cookies['cart_id'] || cookies['cart_id'] || cookies[:cart_id])
  end


  def default_empty_cart(cart_id)
    {
      'id'         => cart_id,
      'currency'   => @args['currency'],
      'lines'      => [],
      'subtotal'   => 0,
      'total'      => 0,
      'updated_at' => Time.now.utc.iso8601
    }
  end

  # One place to call the PageRenderer with our base args + optional extras
  def render_with_renderer(template_json, extra_ctx: {}, status: :ok)
    base = @args.merge('domain' => @domain) # pass domain for metadata/canonical if needed
    result = Pages::PageRenderer.new.render(
      template_name: template_json,
      base_args: base,
      extra_ctx: extra_ctx,
      theme_path: @path,
      preview: false
    )
    set_page_headers(result)
    render html: result.html.html_safe, status: status
  end
end
