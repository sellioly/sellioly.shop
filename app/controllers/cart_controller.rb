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
      
      cart.items = updatedItems
      cart.save
    else
      cart = Cart.new({})
      cart.cart_id = cart_id
      cart.items = [
        {
          variant_id: params[:variant_id],
          title: params[:title],
        }
      ]
      
      cart.save
    end

    render json: cart
  end
end
