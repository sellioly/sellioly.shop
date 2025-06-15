module ShopHelper
  def redis
    Redis.new(url: ENV['REDIS_CABLE_URL'])
  end

  def redis_set(app_domain, shop_id, key, value)
    redis.set("domain:#{app_domain}-shop:#{shop_id}.#{key}", value)
  end

  def redis_get(app_domain, shop_id, key)
    redis.get("domain:#{app_domain}-shop:#{shop_id}.#{key}")
  end

  def get_menu(handle, shop_id, app_domain)
    menu = redis_get(app_domain, shop_id, "menu:#{handle}")

    unless menu == nil
      return JSON.parse(menu)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/menu/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        menu_data = response.parse
        redis_set(app_domain, shop_id, "menu:#{handle}", menu_data.to_json)
        return menu_data
      end
    end
    nil
  end

  def get_product(handle, shop_id, app_domain)
    product = redis_get(app_domain, shop_id, "product:#{handle}")

    unless product == nil
      return JSON.parse(product)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/product/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        product_data = response.parse
        redis_set(app_domain, shop_id, "product:#{handle}", product_data.to_json)
        return product_data
      end
    end
    nil
  end

  def get_products(handles, shop_id, app_domain)
    products = []
    handles.each do |handle|
      product = get_product(handle, shop_id, app_domain)
      # products << product if product

      if product
        products << product
      else
        response = HTTP.post("https://api.sellioly.com/ruby/product/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
        if response.status.success?
          product_data = response.parse
          redis_set(app_domain, shop_id, "product:#{handle}", product_data.to_json)
          products << product_data
        end
      end
    end

    # Return the products array at the end of the method.
    products
  end

  def get_collection(handle, shop_id, app_domain)
    collection = redis_get(app_domain, shop_id, "collection:#{handle}")

    unless collection == nil
      return JSON.parse(collection)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/collection/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        collection_data = response.parse
        redis_set(app_domain, shop_id, "collection:#{handle}", collection_data.to_json)
        return collection_data
      end
    end
    nil
  end

  def get_collections(handles, shop_id, app_domain)
    collections = []
    handles.each do |handle|
      collection = get_collection(handle, shop_id, app_domain)
      # collections << collection if collection

      if collection
        collections << collection
      else
        response = HTTP.post("https://api.sellioly.com/ruby/collection/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
        if response.status.success?
          collection_data = response.parse
          redis_set(app_domain, shop_id, "collection:#{handle}", collection_data.to_json)
          collections << collection_data
        end
      end

    end
    # Return the collections array at the end of the method.
    collections
  end

  def get_shop_id(shop_id)
    shop = redis_get(-1, shop_id, "shop")

    unless shop == nil
      return JSON.parse(shop)
    else
      # If the shop is not found, get it using API call
      response = HTTP.post("https://api.sellioly.com/ruby/store/infos", form: { 'shop_id' => shop_id })

      if response.status.success?
        shop_data = response.parse
        redis_set(-1, shop_id, "shop", shop_data.to_json)
        # Return the shop data after storing it in Redis
        return shop_data
      end
    end
    nil
  end

  def get_metadata(shop_id, app_domain)
    metadata = redis_get(app_domain, shop_id, "metadata")

    unless metadata == nil
      return JSON.parse(metadata)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/metadata/store/list", form: { 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        metadata_data = response.parse
        redis_set(app_domain, shop_id, "metadata", metadata_data.to_json)
        return metadata_data
      end

    end
    nil
  end
end
