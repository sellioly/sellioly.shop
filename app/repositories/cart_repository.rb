# frozen_string_literal: true

class CartRepository
  def initialize(api: Http::ApiClient.new)
    @api = api
  end

  # Returns {cart: {...}} أو nil
  def show(cart_id:, currency: nil)
    res = @api.cart_show(cart_id: cart_id, currency: currency)
    res.ok? ? res.json : nil
  end

  def add_line(cart_id:, currency:, variant_id:, quantity:, properties: {}, idempotency_key: nil)
    res = @api.cart_add_line(cart_id: cart_id, currency: currency, variant_id: variant_id, quantity: quantity, properties: properties, idempotency_key: idempotency_key)
    res.ok? ? res.json : raise_api(res)
  end

  def update_line(cart_id:, line_id:, quantity:)
    res = @api.cart_update_line(cart_id: cart_id, line_id: line_id, quantity: quantity)
    res.ok? ? res.json : raise_api(res)
  end

  def remove_line(cart_id:, line_id:)
    res = @api.cart_remove_line(cart_id: cart_id, line_id: line_id)
    res.ok? ? res.json : raise_api(res)
  end

  private

  def raise_api(res)
    raise StandardError, "Cart API error (#{res.status}): #{res.error.inspect}"
  end
end
