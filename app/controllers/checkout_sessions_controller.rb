# frozen_string_literal: true

class Api::CheckoutSessionsController < ApplicationController
  protect_from_forgery with: :null_session

  def initialize(repo: CheckoutSessionRepository.new)
    super()
    @repo = repo
  end

  # POST /api/checkout_sessions
  # Body examples:
  # { mode:"cart", cart_id:"...", currency:"MAD", locale:"en" }
  # { mode:"buy_now", lines:[{variant_id:"...", quantity:1}], currency:"MAD", locale:"en" }
  def create
    mode = params[:mode].to_s.presence
    unless %w[cart buy_now].include?(mode)
      return render json: { error: "Invalid mode" }, status: :unprocessable_entity
    end

    payload =
      if mode == "cart"
        {
          mode: "cart",
          cart_id: params[:cart_id].to_s,
          currency: (params[:currency].presence || "MAD"),
          locale: (params[:locale].presence || I18n.locale.to_s)
        }
      else
        # buy_now
        line = Array(params[:lines]).first || {}
        {
          mode: "buy_now",
          lines: [{
            variant_id: (line[:variant_id] || line["variant_id"]).to_s,
            quantity: (line[:quantity] || line["quantity"] || 1).to_i
          }],
          currency: (params[:currency].presence || "MAD"),
          locale: (params[:locale].presence || I18n.locale.to_s)
        }
      end

    result = @repo.create(payload: payload, idempotency_key: request.headers["Idempotency-Key"])
    render json: (result.json || result.error), status: (result.ok? ? :ok : :bad_gateway)
  end

  # GET /api/checkout_sessions/:id
  def show
    result = @repo.show(id: params[:id])
    render json: (result.json || result.error), status: (result.ok? ? :ok : :bad_gateway)
  end

  # PATCH /api/checkout_sessions/:id
  def update
    permitted = params.permit(
      contact: [:email, :phone],
      shipping_address: [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      billing_address:  [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      notes: [:text],
      meta: {}
    ).to_h

    result = @repo.update(id: params[:id], payload: permitted)
    render json: (result.json || result.error), status: (result.ok? ? :ok : :bad_gateway)
  end

  # POST /api/checkout_sessions/:id/lock
  def lock
    result = @repo.lock(id: params[:id], idempotency_key: request.headers["Idempotency-Key"])
    render json: (result.json || result.error), status: (result.ok? ? :ok : :bad_gateway)
  end

  # POST /api/checkout_sessions/:id/place
  def place
    result = @repo.place(id: params[:id], idempotency_key: request.headers["Idempotency-Key"])
    render json: (result.json || result.error), status: (result.ok? ? :ok : :bad_gateway)
  end
end
