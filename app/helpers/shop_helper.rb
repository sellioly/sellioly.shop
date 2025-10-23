# app/helpers/shop_helper.rb (ONLY the methods shown here)
module ShopHelper
  def catalog_repo
    @catalog_repo ||= CatalogRepository.new
  end

  def get_product(handle, shop_id, app_domain)
    catalog_repo.get_product(handle: handle, shop_id: shop_id, domain: app_domain)
  end

  def get_products(handles, shop_id, app_domain)
    Array(handles).filter_map { |h| get_product(h, shop_id, app_domain) }
  end

  def get_collection(handle, shop_id, app_domain)
    catalog_repo.get_collection(handle: handle, shop_id: shop_id, domain: app_domain)
  end

  def get_collections(handles, shop_id, app_domain)
    Array(handles).filter_map { |h| get_collection(h, shop_id, app_domain) }
  end

  def get_menu(handle, shop_id, app_domain)
    catalog_repo.get_menu(handle: handle, shop_id: shop_id, domain: app_domain)
  end

  def get_metadata(shop_id, app_domain)
    catalog_repo.get_metadata(shop_id: shop_id, domain: app_domain)
  end

  def get_shop_id(shop_id)
    catalog_repo.get_shop_info(shop_id: shop_id)
  end
end
