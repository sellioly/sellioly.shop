# frozen_string_literal: true
class CheckoutSessionRepository < BaseRepository
  def create(payload:, idempotency_key: nil)
    @api.create_checkout_session(payload: payload, idempotency_key: idempotency_key)
  end

  def show(id:)
    @api.show_checkout_session(id: id)
  end

  def update(id:, payload:)
    @api.update_checkout_session(id: id, payload: payload)
  end

  def place(id:, idempotency_key: nil)
    @api.place_checkout_session(id: id, idempotency_key: idempotency_key)
  end
end