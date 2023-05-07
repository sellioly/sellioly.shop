class CartController < ApplicationController
  public def add
    # code here
    cart_id = params[:cart_id]

    cart = Cart.find_by(cart_id: cart_id)
    if cart
      updatedItems = cart.items

      updatedItems.push({
        variant_id: params[:variant_id],
        title: params[:title],
      })
      
      cart.items = updatedItems.to_json
      cart.save
    else
      cart = Cart.new({})
      cart.cart_id = cart_id
      newItems = [
        {
          variant_id: params[:variant_id],
          title: params[:title],
        }
      ]

      cart.items = newItems.to_json
      cart.save
    end

    render json: cart
  end
end
