# frozen_string_literal: true

class CartRepository < BaseRepository
  # يعيد دائمًا Http::Result
  def show(cart_id:, currency: nil)
    result = @api.cart_show(cart_id: cart_id, currency: currency)
    result.json.is_a?(Hash) ? result.json['data'] : nil
  end

  def add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
    @api.cart_add_line(
      cart_id: cart_id,
      currency: currency,
      variant_id: variant_id,
      quantity: quantity,
      properties: properties,
      idempotency_key: idempotency_key
    )
  end

  def update_line(cart_id:, line_id:, quantity:)
    @api.cart_update_line(cart_id: cart_id, line_id: line_id, quantity: quantity)
  end

  def remove_line(cart_id:, line_id:)
    @api.cart_remove_line(cart_id: cart_id, line_id: line_id)
  end
end
