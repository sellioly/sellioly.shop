# app/repositories/order_repository.rb
# frozen_string_literal: true

class OrderRepository < BaseRepository
  # GET /orders/:id
  def show(order_id:)
    @api.get_order(order_id)
  end

  # POST /orders/:id/cancel
  def cancel(order_id:, idempotency_key: nil)
    @api.cancel_order(order_id, idempotency_key: idempotency_key)
  end
end