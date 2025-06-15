module ShopHelper
  def redis
    Redis.new(url: ENV['REDIS_CABLE_URL'])
  end

  def redis_set(app_domain, shop_id, key, value)
    redis.set("domain:#{app_domain}-shop:#{shop_id}.#{key}", value)
  end

  def redis_setex(app_domain, shop_id, key, value, ttl_seconds = 300)
    # By default, set the TTL to 5 minutes (300 seconds)
    redis.setex("domain:#{app_domain}-shop:#{shop_id}.#{key}", ttl_seconds, value)
  end

  def redis_get(app_domain, shop_id, key)
    redis.get("domain:#{app_domain}-shop:#{shop_id}.#{key}")
  end

  def get_menu(handle, shop_id, app_domain)
    return nil if handle.nil? || handle.empty?

    menu = redis_get(app_domain, shop_id, "menu:#{handle}")

    unless menu.nil?
      return nil if menu == "NULL"
      return JSON.parse(menu)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/menu/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        menu_data = response.parse
        redis_set(app_domain, shop_id, "menu:#{handle}", menu_data.to_json)
        return menu_data
      else
        redis_setex(app_domain, shop_id, "menu:#{handle}", "NULL")
      end
    end
    nil
  end

  def get_product(handle, shop_id, app_domain)
    cached_product = redis_get(app_domain, shop_id, "product:#{handle}")

    unless cached_product.nil?
      return nil if cached_product == "NULL"
      return JSON.parse(cached_product)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/product/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        product_data = response.parse
        redis_set(app_domain, shop_id, "product:#{handle}", product_data.to_json)
        return product_data
      else
        redis_setex(app_domain, shop_id, "product:#{handle}", "NULL")
      end
    end
    nil
  end

  def get_products(handles, shop_id, app_domain)
    products = []
    handles.each do |handle|
      product = get_product(handle, shop_id, app_domain)
      products << product if product
    end
    products
  end

  def get_collection(handle, shop_id, app_domain)
    collection = redis_get(app_domain, shop_id, "collection:#{handle}")

    unless collection.nil?
      return nil if collection == "NULL"
      return JSON.parse(collection)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/collection/get-by-handle", form: { 'handle' => handle, 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        collection_data = response.parse
        redis_set(app_domain, shop_id, "collection:#{handle}", collection_data.to_json)
        return collection_data
      else
        redis_setex(app_domain, shop_id, "collection:#{handle}", "NULL")
      end
    end
    nil
  end

  def get_collections(handles, shop_id, app_domain)
    collections = []
    handles.each do |handle|
      collection = get_collection(handle, shop_id, app_domain)
      collections << collection if collection
    end
    collections
  end

  def get_shop_id(shop_id)
    shop = redis_get(-1, shop_id, "shop")

    unless shop.nil?
      return nil if shop == "NULL"
      return JSON.parse(shop)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/store/infos", form: { 'shop_id' => shop_id })
      if response.status.success?
        shop_data = response.parse
        redis_set(-1, shop_id, "shop", shop_data.to_json)
        return shop_data
      else
        redis_setex(-1, shop_id, "shop", "NULL")
      end
    end
    nil
  end

  def get_metadata(shop_id, app_domain)
    metadata = redis_get(app_domain, shop_id, "metadata")

    unless metadata.nil?
      return nil if metadata == "NULL"
      return JSON.parse(metadata)
    else
      response = HTTP.post("https://api.sellioly.com/ruby/metadata/store/list", form: { 'shop_id' => shop_id, 'app_domain' => app_domain })
      if response.status.success?
        metadata_data = response.parse
        redis_set(app_domain, shop_id, "metadata", metadata_data.to_json)
        return metadata_data
      else
        redis_setex(app_domain, shop_id, "metadata", "NULL")
      end
    end
    nil
  end
end