# frozen_string_literal: true

class CartRepository < BaseRepository
  # يعيد دائمًا Http::Result
  def show(cart_id:, currency: nil)
    res = @api.cart_show(cart_id: cart_id, currency: currency)
    ok_json_or_result(res)
  end

  def add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
    res = @api.cart_add_line(
      cart_id: cart_id,
      currency: currency,
      variant_id: variant_id,
      quantity: quantity,
      properties: properties,
      idempotency_key: idempotency_key
    )
    ok_json_or_result(res)
  end

  def update_line(cart_id:, line_id:, quantity:)
    res = @api.cart_update_line(cart_id: cart_id, line_id: line_id, quantity: quantity)
    ok_json_or_result(res)
  end

  def remove_line(cart_id:, line_id:)
    res = @api.cart_remove_line(cart_id: cart_id, line_id: line_id)
    ok_json_or_result(res)
  end
end
