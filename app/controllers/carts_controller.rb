# frozen_string_literal: true

class CartsController < Api::BaseController
  before_action :initialize_shop  # يضبط @shop_id, @domain, @path, @args

  def initialize(repo: CartRepository.new)
    super()
    @repo = repo
  end

  # GET /cart?cart_id?&currency?
  def show
    cart_id  = params[:cart_id].presence || cookies[:cart_id]
    currency = @args['currency']

    result = @repo.show(cart_id: cart_id, currency: currency)

    ensure_cart_cookie!(result.json) if result.ok?
    render json: { cart: result.json }, status: map_status(result.status)
  end

  # POST /cart/lines
  # body: { variant_id, quantity, properties? , cart_id? }
  # query: sections=mini_cart,cart_badge&current_url=/...
  def add_line
    cart_id    = params[:cart_id].presence || cookies[:cart_id]
    currency   = @args['currency']

    variant_id = params.require(:variant_id).to_s
    quantity   = params.require(:quantity).to_i
    properties = extract_properties(params[:properties])

    result = @repo.add_line(
      cart_id: cart_id,
      currency: currency,
      variant_id: variant_id,
      quantity: quantity,
      properties: properties,
      idempotency_key: current_idempotency_key # من الـ concern
    )

    if result.ok?
      ensure_cart_cookie!(result.json)
      render json: { cart: result.json, sections: render_sections_if_requested(result.json) },
             status: map_status(result.status)
    else
      render json: (result.json || { error: result.error || 'Cart add failed' }),
             status: map_status(result.status)
    end
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  # PATCH /cart/lines/:id
  def update_line
    cart_id = params[:cart_id].presence || cookies[:cart_id]
    line_id = params.require(:id).to_s
    qty     = params.require(:quantity).to_i

    result = @repo.update_line(cart_id: cart_id, line_id: line_id, quantity: qty)

    if result.ok?
      ensure_cart_cookie!(result.json)
      render json: { cart: result.json, sections: render_sections_if_requested(result.json) },
             status: map_status(result.status)
    else
      render json: (result.json || { error: result.error || 'Cart update failed' }),
             status: map_status(result.status)
    end
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  # DELETE /cart/lines/:id
  def remove_line
    cart_id = params[:cart_id].presence || cookies[:cart_id]
    line_id = params.require(:id).to_s

    result = @repo.remove_line(cart_id: cart_id, line_id: line_id)

    if result.ok?
      ensure_cart_cookie!(result.json)
      render json: { cart: result.json, sections: render_sections_if_requested(result.json) },
             status: map_status(result.status)
    else
      render json: (result.json || { error: result.error || 'Cart remove failed' }),
             status: map_status(result.status)
    end
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def extract_properties(props)
    return {} if props.nil?
    return props.to_unsafe_h if props.is_a?(ActionController::Parameters)
    props
  end

  def ensure_cart_cookie!(cart_payload)
    return unless cart_payload.is_a?(Hash) && cart_payload['id'].present?

    if cookies[:cart_id] != cart_payload['id']
      cookies[:cart_id] = { value: cart_payload['id'], path: '/', httponly: true, same_site: :lax }
    end

    @args['cart'] = cart_payload # متوفر للـ templates/snippets
  end

  # sections=mini_cart,cart_badge   current_url=/cart
  def render_sections_if_requested(cart_payload)
    return {} unless params[:sections].present?

    section_ids = params[:sections].to_s.split(',').map(&:strip).reject(&:empty?)
    return {} if section_ids.empty?

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

    section_ids.each_with_object({}) do |name, h|
      rel = if name.include?('/')
              "#{name}.liquid"
            else
              %W[snippets/#{name}.liquid components/#{name}.liquid sections/#{name}.liquid]
                .find { |p| store.exists?(p) } || "snippets/#{name}.liquid"
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
