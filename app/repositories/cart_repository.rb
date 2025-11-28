# frozen_string_literal: true

class CartRepository < BaseRepository
  # يعيد دائمًا Http::Result
  def show(cart_id:, currency: nil)
    result = @api.cart_show(cart_id: cart_id, currency: currency)
    result.ok? ? (result.json.is_a?(Hash) ? result.json['data'] : nil) : result 
  end

  def add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
    result = @api.cart_add_line(
      cart_id: cart_id,
      currency: currency,
      variant_id: variant_id,
      quantity: quantity,
      properties: properties,
      idempotency_key: idempotency_key
    )
    result.ok? ? (result.json.is_a?(Hash) ? result.json['data'] : nil) : result 
  end

  def update_line(cart_id:, line_id:, quantity:)
    result = @api.cart_update_line(cart_id: cart_id, line_id: line_id, quantity: quantity)
    result.ok? ? (result.json.is_a?(Hash) ? result.json['data'] : nil) : result 
  end

  def remove_line(cart_id:, line_id:)
    result = @api.cart_remove_line(cart_id: cart_id, line_id: line_id)
    result.ok? ? (result.json.is_a?(Hash) ? result.json['data'] : nil) : result 
  end
end
