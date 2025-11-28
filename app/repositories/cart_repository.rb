# frozen_string_literal: true

class CartRepository < BaseRepository
  # Returns Http::Result with unwrapped json (defensive unwrapping of Laravel's { data: ... } wrapper)
  def show(cart_id:, currency: nil)
    result = @api.cart_show(cart_id: cart_id, currency: currency)
    unwrap_result(result)
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
    unwrap_result(result)
  end

  def update_line(cart_id:, line_id:, quantity:)
    result = @api.cart_update_line(cart_id: cart_id, line_id: line_id, quantity: quantity)
    unwrap_result(result)
  end

  def remove_line(cart_id:, line_id:)
    result = @api.cart_remove_line(cart_id: cart_id, line_id: line_id)
    unwrap_result(result)
  end

  private

  # Unwrap Laravel's { data: ... } wrapper if present (defensive - works with or without wrapping)
  def unwrap_result(result)
    return result unless result.ok? && result.json.is_a?(Hash)
    
    # If wrapped, unwrap it by modifying the result's json
    if result.json.key?('data')
      # Create new Result with unwrapped json (preserve all other fields)
      Http::ApiClient::Result.new(
        ok?: result.ok?,
        status: result.status,
        json: result.json['data'],
        error: result.error,
        headers: result.headers
      )
    else
      result
    end
  end
end
