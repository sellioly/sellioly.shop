# frozen_string_literal: true

class CheckoutSessionRepository
  def initialize(client: Http::ApiClient.new)
    @client = client
  end

  # mode: "cart" | "buy_now"
  # For "cart":  payload = { mode:"cart",  cart_id:, currency:, locale: }
  # For "buy_now": payload = { mode:"buy_now", lines:[{variant_id:,quantity:}], currency:, locale: }
  def create(payload:, idempotency_key: nil)
    @client.create_checkout_session(payload: payload, idempotency_key: idempotency_key)
  end

  def show(id:)
    @client.show_checkout_session(id: id)
  end

  # payload may include: contact, shipping_address, billing_address, notes, etc.
  def update(id:, payload:)
    @client.update_checkout_session(id: id, payload: payload)
  end

  def lock(id:, idempotency_key: nil)
    @client.lock_checkout_session(id: id).tap { |_| } # ApiClient already sends POST
  end

  def place(id:, idempotency_key: nil)
    @client.place_checkout_session(id: id)
  end
end
