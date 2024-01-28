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

    if menu == nil
      endpoint = "menu/get-by-handle"
      response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'handle' => handle, 'user_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        response_string = response.body.to_s
        redis_set(app_domain, shop_id, "menu:#{handle}", response_string)

        return response.parse
      end
    else
      return JSON.parse(menu)
    end
    nil
  end

  def get_product(handle, shop_id, app_domain)
    product = redis_get(app_domain, shop_id, "product:#{handle}")

    if product == nil
      endpoint = "product/get-by-handle"
      response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'handle' => handle, 'user_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        response_string = response.body.to_s
        redis_set(app_domain, shop_id, "product:#{handle}", response_string)

        return response.parse
      end
    else
      return JSON.parse(product)
    end
    nil
  end



  def get_products(handles, shop_id, app_domain)
    products = []
    handles.each do |handle|
      product = get_product(handle, shop_id, app_domain)
      products << product if product
    end

    # Return the products array at the end of the method.
    products
  end

  def get_collection(handle, shop_id, app_domain)
    collection = redis_get(app_domain, shop_id, "collection:#{handle}")

    if collection == nil
      endpoint = "collection/get-by-handle"
      response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'handle' => handle, 'user_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        response_string = response.body.to_s
        redis_set(app_domain, shop_id, "collection:#{handle}", response_string)

        return response.parse
      end
    else
      return JSON.parse(collection)
    end
    nil
  end

  def get_collections(handles, shop_id, app_domain)
    collections = []
    handles.each do |handle|
      collection = get_collection(handle, shop_id, app_domain)
      collections << collection if collection
    end
    # Return the collections array at the end of the method.
    collections
  end


  def get_shop(app_domain)
    shop = redis_get(app_domain, -1, "shop")

    if shop == nil
      endpoint = "store/infos"
      response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'app_domain' => app_domain })
      if response.status.success?
        response_string = response.body.to_s
        redis_set(app_domain, -1, "shop", response_string)

        return response.parse
      end
    else
      return JSON.parse(shop)
    end
    nil
  end

  def get_metadata(shop_id, app_domain)
    metadata = redis_get(app_domain, shop_id, "metadata")

    if metadata == nil
      endpoint = "metadata/store/list"
      response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'meta_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        response_string = response.body.to_s
        redis_set(app_domain, shop_id, "metadata", response_string)

        return response.parse
      end
    else
      return JSON.parse(metadata)
    end
    nil
  end

end
