class CartController < ApplicationController
  public def add
    if !params[:cart_id].present? || !params[:quantity].present?
      render json: { error: 'Bad Request' }, status: :bad_request
    end

    cart_id = params[:cart_id]
    quantity = params[:quantity]

    cart = Cart.find_by(cart_id: cart_id)
    if cart
      updatedItems = cart.items

      updatedItems.push({
        variant_id: '74026596418503',
        quantity: quantity,
        title: 'JACKET HOMME',
        price: 300,
        image_url: 'https://sellioly.s3.eu-west-3.amazonaws.com/100159510462595346/products/duPchDee4divN7OWaN34GIShN8Q9M3JO9pLJsFAM.jpg',
        options: {
          option1: {
            name: "color",
            value: "black"
          },
          option2: {
            name: "size",
            value: "M"
          }
        }
      })
      
      cart.items = updatedItems
      cart.save
    else
      cart = Cart.new({})
      cart.cart_id = cart_id
      cart.items = [
        {
          variant_id: '74026596418503',
          quantity: params[:quantity],
          title: 'JACKET HOMME',
          price: 300,
          image_url: 'https://sellioly.s3.eu-west-3.amazonaws.com/100159510462595346/products/duPchDee4divN7OWaN34GIShN8Q9M3JO9pLJsFAM.jpg',
          options: {
            option1: {
              name: "color",
              value: "black"
            },
            option2: {
              name: "size",
              value: "M"
            }
          }
        }
      ]

      cart.save
    end

    render json: cart
  end

  public def list
    render json: Cart.all
  end
end
