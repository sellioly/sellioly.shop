class CartController < ApplicationController
  public def add
    # code here
    cart_id = params[:cart_id]

    cart = Cart.find_by(cart_id: cart_id)
    if cart
      
    else
      cart = Cart.new({})
      cart.cart_id = cart_id
      cart.items = [
        {
          variant_id: 12313,
          title: 'new product'
        }
      ]

      cart.save
    end

    render json: cart
  end
end
