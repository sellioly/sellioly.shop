# frozen_string_literal: true
class CheckoutSessionsController < BaseController
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
    render_result(result)
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
    # Check terms acceptance
    accept_terms = params[:accept_terms]
    unless accept_terms == true || accept_terms.to_s.downcase == "true"
      return render json: { error: "Terms must be accepted" }, status: :unprocessable_entity
    end

    result = @repo.place(id: params[:id], idempotency_key: current_idempotency_key)
    render_result(result)
  end

  private

  def build_cart_payload
    {
      cart_id: params[:cart_id].to_s,
      customer: {
        name: params[:customer_name].presence,
        email: params[:customer_email].presence,
        phone: params[:customer_phone].presence
      }
    }
  end

  def build_buy_now_payload
    {
      buy_now: true,
      variant_id: params.require(:variant_id).to_s,
      quantity:   params.require(:quantity).to_i,
      customer: {
        name: params[:customer_name].presence,
        email: params[:customer_email].presence,
        phone: params[:customer_phone].presence
      }
    }
  end

  def update_params
    params.permit(
      :notes,
      customer: [:name, :email, :phone],
      shipping_address: [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      billing_address:  [:name, :phone, :country, :city, :address1, :address2, :postal_code],
      meta: {}
    ).to_h
  end
end
