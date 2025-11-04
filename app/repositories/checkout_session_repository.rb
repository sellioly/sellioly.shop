# frozen_string_literal: true
class CheckoutSessionRepository < BaseRepository
  def create(payload:, idempotency_key: nil)
    res = @api.create_checkout_session(payload: payload, idempotency_key: idempotency_key)
    ok_json_or_result(res)
  end

  def show(id:)
    ok_json_or_result(@api.show_checkout_session(id: id))
  end

  def update(id:, payload:)
    ok_json_or_result(@api.update_checkout_session(id: id, payload: payload))
  end

  def lock(id:, idempotency_key: nil)
    ok_json_or_result(@api.lock_checkout_session(id: id, idempotency_key: idempotency_key))
  end

  def place(id:, idempotency_key: nil)
    ok_json_or_result(@api.place_checkout_session(id: id, idempotency_key: idempotency_key))
  end
end