# frozen_string_literal: true

class CartsController < ApplicationController
  protect_from_forgery with: :null_session

  before_action :initialize_shop # يضبط @shop_id, @domain, @path, @args

  # GET /cart
  # params: cart_id?, currency?
  def show
    cart_id  = params[:cart_id] || cookies[:cart_id]
    currency = @args['currency']

    repo  = CartRepository.new
    cart  = repo.show(cart_id: cart_id, currency: currency)

    # لو مفيش cart_id جالك من العميل والـ API أنشأ جديد، خزِّنه في الكوكيز
    if cart && cart['id'] && cookies[:cart_id] != cart['id']
      cookies[:cart_id] = { value: cart['id'], path: '/', httponly: true, same_site: :lax }
    end

    render json: { cart: cart }.compact
  end

  # POST /cart/lines
  # body: { variant_id, quantity, properties? , cart_id? }
  # query: sections=mini_cart,cart_badge&current_url=/...
  def add_line
    cart_id   = params[:cart_id] || cookies[:cart_id]
    currency  = @args['currency']
    variant_id = params.require(:variant_id)
    quantity   = params.require(:quantity).to_i
    properties = params[:properties].is_a?(ActionController::Parameters) ? params[:properties].to_unsafe_h : (params[:properties] || {})
    idem_key   = request.headers['X-Idempotency-Key'] || SecureRandom.uuid

    repo = CartRepository.new
    payload = repo.add_line(
      cart_id: cart_id,
      currency: currency,
      variant_id: variant_id,
      quantity: quantity,
      properties: properties,
      idempotency_key: idem_key
    )

    ensure_cart_cookie!(payload)

    render json: { cart: payload, sections: render_sections_if_requested(payload) }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error(at: 'cart_add_line', err: e.class.name, msg: e.message)
    render json: { error: 'Cart add failed' }, status: :bad_gateway
  end

  # PATCH /cart/lines/:id
  def update_line
    cart_id = params[:cart_id] || cookies[:cart_id]
    line_id = params.require(:id)
    qty     = params.require(:quantity).to_i

    repo    = CartRepository.new
    payload = repo.update_line(cart_id: cart_id, line_id: line_id, quantity: qty)

    ensure_cart_cookie!(payload)

    render json: { cart: payload, sections: render_sections_if_requested(payload) }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error(at: 'cart_update_line', err: e.class.name, msg: e.message)
    render json: { error: 'Cart update failed' }, status: :bad_gateway
  end

  # DELETE /cart/lines/:id
  def remove_line
    cart_id = params[:cart_id] || cookies[:cart_id]
    line_id = params.require(:id)

    repo    = CartRepository.new
    payload = repo.remove_line(cart_id: cart_id, line_id: line_id)

    ensure_cart_cookie!(payload)

    render json: { cart: payload, sections: render_sections_if_requested(payload) }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error(at: 'cart_remove_line', err: e.class.name, msg: e.message)
    render json: { error: 'Cart remove failed' }, status: :bad_gateway
  end

  private

  def ensure_cart_cookie!(payload)
    return unless payload && payload['id']
    cookies[:cart_id] = { value: payload['id'], path: '/', httponly: true, same_site: :lax }
    @args['cart'] = payload # متوفر للـ snippets
  end

  # sections=mini_cart,cart_badge   current_url=/cart
  def render_sections_if_requested(cart_payload)
    return {} unless params[:sections].present?
    section_ids = params[:sections].to_s.split(',').map(&:strip).reject(&:empty?)
    return {} if section_ids.empty?

    # نستخدم PageRenderer بنفس سياق الثيم الحالي
    store     = Theme::ThemeStore.new(root: @path)
    compiler  = Theme::TemplateCompiler.new
    renderer  = Theme::LiquidRenderer.new

    assigns = @args.merge('cart' => cart_payload, 'current_url' => params[:current_url].to_s)
    registers = {
      'theme_store'    => store,
      'compiler'       => compiler,
      'renderer'       => renderer,
      'preview'        => false,
      'include_depth'  => 0
    }

    # كل اسم قسم/سنيبت بنحاول نلاقِيه في snippets→components→sections
    section_ids.each_with_object({}) do |name, h|
      rel = if name.include?('/')
        "#{name}.liquid"
      else
        %W[snippets/#{name}.liquid components/#{name}.liquid sections/#{name}.liquid].find { |p| store.exists?(p) } || "snippets/#{name}.liquid"
      end
      if store.exists?(rel)
        tpl  = compiler.compile(theme_store: store, rel_path: rel)
        html = renderer.safe_render(tpl, assigns: assigns, theme_store: store, registers: registers)
        h[name] = html
      else
        h[name] = ""
      end
    end
  end
end
