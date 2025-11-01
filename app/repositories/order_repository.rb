class OrderRepository
  def initialize(api: Http::ApiClient.new)
    @api = api
  end

  # Create a new order (COD checkout)
  def create(payload)
    res = @api.create_order(payload)
    return res.json if res.ok?
    raise "Order creation failed: #{res.error || res.status}"
  end

  # Fetch existing order
  def show(order_id)
    res = @api.get_order(order_id)
    return res.json if res.ok?
    raise "Order not found: #{res.error || res.status}"
  end

  # Cancel order (if still pending/confirmed)
  def cancel(order_id)
    res = @api.cancel_order(order_id)
    return res.json if res.ok?
    raise "Order cancel failed: #{res.error || res.status}"
  end
end