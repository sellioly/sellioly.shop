class CartController < ApplicationController

  public def add
    # unless cookies[:cart_id].present?
    unless params[:cart_id].present?
      render json: { error: 'cart_id required!' }, status: :bad_request
      return
    end
    if !params[:variant_id].present? || !params[:quantity].present?
      render json: { error: 'variant_id and quantity required' }, status: :bad_request
      return 
    end

    cart_id = params[:cart_id]
    variant_id = params[:variant_id]
    quantity = params[:quantity]

    cart = Cart.find_by(cart_id: cart_id)
    unless cart
      render json: { error: 'Cart not found' }, status: :bad_request
      return
    end

    response = HTTP.post("https://api.sellioly.com/server/product/variant/get-by-id", :form => { 'variant_id' => variant_id })
    unless response.status.success?
      render json: { error: 'error on getting the variant!' }, status: :bad_request
      return
    end
    variant = response.parse

    updatedItems = cart.items
    updatedItems.push({
      variant_id: variant_id,
      quantity: quantity,
      title: variant['title'],
      price: variant['price'],
      image: variant['image'],
      options: variant['options']
    })
    
    cart.items = updatedItems
    cart.save

    render json: cart
  end

  public def get
    unless params[:cart_id].present?
      render json: { error: 'Bad Request' }, status: :bad_request
      return
    end

    cart = Cart.find_by(cart_id: params[:cart_id])
    if cart.nil?
      render json: { error: 'Bad Request' }, status: :bad_request
      return  
    end

    render json: cart
  end
end
