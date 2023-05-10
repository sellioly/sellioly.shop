class CartController < ApplicationController
  public def add
    if !params[:variant_id].present? || !params[:quantity].present? || !cookies[:cart_id].present?
      render json: { error: 'Bad Request' }, status: :bad_request
      return 
    end

    cart_id = cookies[:cart_id]
    variant_id = params[:variant_id]
    quantity = params[:quantity]

    cart = Cart.find_by(cart_id: cart_id)
    if !cart
      render json: { error: 'Cart not found' }, status: :bad_request
    end

    if cart
      updatedItems = cart.items
      updatedItems.push({
        variant_id: variant_id,
        quantity: quantity,
        title: 'JACKET HOMME',
        price: 300,
        image_url: 'https://sellioly.s3.eu-west-3.amazonaws.com/100159510462595346/products/duPchDee4divN7OWaN34GIShN8Q9M3JO9pLJsFAM.jpg',
        options: [
          {
            name: "color",
            value: "black"
          },
          {
            name: "size",
            value: "M"
          }
        ]
      })
      
      cart.items = updatedItems
      cart.save
    end

    render json: cart
  end

  public def get
    if !params[:cart_id].present?
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
