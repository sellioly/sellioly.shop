class CartController < ShopController

  public def add
    unless check_store
      return
    end
    @path = Rails.root.to_s + @store.template_path.to_s

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

    exist = false
    updatedItems = cart.items
    updatedItems.each { |item|
      if item['variant_id'] == variant_id
        item['quantity'] = item['quantity'].to_i + quantity.to_i 
        exist = true
      end
    }

    unless exist
      updatedItems.push({
        variant_id: variant_id,
        quantity: quantity,
        title: variant['title'],
        price: variant['price'],
        image: variant['image'],
        options: variant['options']
      })
    end
    
    cart.subtotal += variant['price'].to_f * quantity.to_i
    cart.items = updatedItems
    cart.save

    # because we inherit from shop_controller
    @args['cart'] = cart.as_json

    # render sections
    sections = {}
    if params[:sections].present?
      section_ids = params[:sections].split(',')
      section_ids.each { |section_id|
        sections[section_id] = render_section(section_id)
      }
    end

    render json: sections
  end

  public def remove
    unless check_store
      return
    end
    @path = Rails.root.to_s + @store.template_path.to_s

    # unless cookies[:cart_id].present?
    unless params[:cart_id].present?
      render json: { error: 'cart_id required!' }, status: :bad_request
      return
    end
    if !params[:variant_id].present?
      render json: { error: 'variant_id required' }, status: :bad_request
      return 
    end

    cart_id = params[:cart_id]
    variant_id = params[:variant_id]

    cart = Cart.find_by(cart_id: cart_id)
    unless cart
      render json: { error: 'Cart not found' }, status: :bad_request
      return
    end

    newItems = []
    cart.items.each { |item|
      if item['variant_id'] == variant_id
        cart.subtotal -= item['price'].to_f * item['quantity'].to_i
      else
        newItems.push(item)
      end
    }
    
    cart.items = newItems
    cart.save

    # because we inherit from shop_controller
    @args['cart'] = cart.as_json

    # render sections
    sections = {}
    if params[:sections].present?
      section_ids = params[:sections].split(',')
      section_ids.each { |section_id|
        sections[section_id] = render_section(section_id)
      }
    end

    render json: sections
  end

  public def selectOption 
    unless check_store
      return
    end

    unless params[:product_handle].present? || params[:options].present?
      render json: { error: 'params required!' }, status: :bad_request
      return
    end

    response = HTTP.post("https://api.sellioly.com/server/product/variant/get-by-options", 
      :form => { 'app_domain' => @domain, 'product_handle' => params[:product_handle], 'options[]' => params[:options] }
    )

    unless response.status.success?
      render json: { error: 'error on getting the variant!' }, status: :bad_request
      return
    end

    render json: response.parse
  end

end
