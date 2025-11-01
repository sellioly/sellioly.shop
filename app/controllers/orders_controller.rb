# app/controllers/orders_controller.rb
class OrdersController < ShopController
  # POST /orders
  def create
    ensure_store_context
    repo = OrderRepository.new

    payload = {
      cart_id: cookies[:cart_id],
      customer: {
        email: params[:email],
        phone: params[:phone],
        name: params[:name]
      },
      shipping_address: {
        name: params[:shipping_name],
        phone: params[:shipping_phone],
        country: params[:shipping_country],
        city: params[:shipping_city],
        address1: params[:shipping_address1],
        postal_code: params[:shipping_postal_code]
      },
      notes: params[:notes],
      payment_method: "cash_on_delivery"
    }

    order_data = repo.create(payload)
    order = order_data["order"]

    # Optional: clear cart cookie after successful order
    cookies.delete(:cart_id)

    render json: {
      message: "Order created successfully",
      order: order,
      next_action: order_data["next_action"]
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /orders/:id
  def show
    repo = OrderRepository.new
    order_data = repo.show(params[:id])
    render json: order_data
  rescue => e
    render json: { error: e.message }, status: :not_found
  end

  # POST /orders/:id/cancel
  def cancel
    repo = OrderRepository.new
    order_data = repo.cancel(params[:id])
    render json: order_data
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
