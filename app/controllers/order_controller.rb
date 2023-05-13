class OrderController < ApplicationController

  public def add
    unless check_store
      return
    end

    unless @store
      content_not_found
      return
    end

    # unless cookies[:cart_id].present?
    unless params[:cart_id].present?
      render json: { error: 'cart_id required!' }, status: :bad_request
      return
    end
    if !params[:full_name].present? || !params[:phone].present?
      render json: { error: 'fields required' }, status: :bad_request
      return 
    end
    
    cart = Cart.find_by(cart_id: params[:cart_id])
    if !cart || cart.items.size == 0
      render json: { error: 'Cart not found or empty!' }, status: :bad_request
      return
    end

    response = HTTP.post("https://api.sellioly.com/server/product/variant/get-by-id", :form => { 
      'app_domain' => @domain,
      'variant_id' => params[:variant_id],
      'full_name' => params[:full_name],
      'email' => params[:email],
      'city' => params[:city],
      'address' => params[:address],
      'phone' => params[:phone],
      'order_items' => cart
    })
    unless response.status.success?
      render json: { error: 'error on create the order!' }, status: :bad_request
      return
    end
    result = response.parse

    render json: result
  end

end
