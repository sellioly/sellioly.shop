# app/repositories/order_repository.rb
# frozen_string_literal: true

class OrderRepository < BaseRepository
  # GET /orders/:id
  def show(order_id:)
    res = @api.get_order(order_id)
    ok_json_or_result(res)
  end

  # POST /orders/:id/cancel
  def cancel(order_id:, idempotency_key: nil)
    res = @api.cancel_order(order_id, idempotency_key: idempotency_key)
    ok_json_or_result(res)
  end
end