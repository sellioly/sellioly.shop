# frozen_string_literal: true
class Api::CheckoutSessionsController < Api::BaseController
  def initialize(repo: CheckoutSessionRepository.new)
    super()
    @repo = repo
  end

  # POST /api/checkout_sessions
  def create
    mode = params[:mode].to_s
    payload =
      case mode
      when "cart"    then build_cart_payload
      when "buy_now" then build_buy_now_payload
      else
        return render json: { error: "Invalid mode" }, status: :unprocessable_entity
      end

    result = @repo.create(payload: payload, idempotency_key: current_idempotency_key)
    render_result(
      result,
      default_ok: :created,
      location_for: ->(id) { id ? api_checkout_session_url(id) : nil }
    )
  end

  # GET /api/checkout_sessions/:id
  def show
    result = @repo.show(id: params[:id])
    render_result(result)
  end

  # PATCH /api/checkout_sessions/:id
  def update
    result = @repo.update(id: params[:id], payload: update_params)
    render_result(result)
  end

  # POST /api/checkout_sessions/:id/lock
  def lock
    result = @repo.lock(id: params[:id], idempotency_key: current_idempotency_key)
    render_result(result)
  end

  # POST /api/checkout_sessions/:id/place
  def place
    result = @repo.place(id: params[:id], idempotency_key: current_idempotency_key)
    render_result(result)
  end

  private

  def build_cart_payload
    {
      mode: "cart",
      cart_id: params[:cart_id].to_s,
      currency: params[:currency].presence || "MAD",
      locale: params[:locale].presence || I18n.locale.to_s
    }
  end

  def build_buy_now_payload
    line = if params[:lines].present?
      raw = Array(params[:lines]).first || {}
      { variant_id: (raw[:variant_id] || raw["variant_id"]).to_s, quantity: (raw[:quantity] || raw["quantity"] || 1).to_i }
    else
      { variant_id: params[:variant_id].to_s, quantity: (params[:quantity] || 1).to_i }
    end

    {
      mode: "buy_now",
      lines: [line],
      currency: params[:currency].presence || "MAD",
      locale: params[:locale].presence || I18n.locale.to_s
    }
  end

  def update_params
    params.permit(
      contact: [:email, :phone],
      shipping_address: [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      billing_address:  [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      notes: [:text],
      meta: {}
    ).to_h
  end
end
