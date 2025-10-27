# app/lib/cache/catalog_version.rb
# frozen_string_literal: true

module Cache
  module CatalogVersion
    module_function

    # For collection listing pages (includes global + that collection)
    def for_collection(shop_id:, collection_handle:, vs: Infra::VersionStore.new)
      s = vs.get_shop_catalog(shop_id)
      c = vs.get_collection(shop_id, collection_handle.to_s)
      "s#{s}-c#{c}"
    end

    # For product page (includes global + that product)
    def for_product(shop_id:, product_handle:, vs: Infra::VersionStore.new)
      s = vs.get_shop_catalog(shop_id)
      p = vs.get_product(shop_id, product_handle.to_s)
      "s#{s}-p#{p}"
    end

    # For menus
    def for_menu(shop_id:, menu_handle:, vs: Infra::VersionStore.new)
      m = vs.get_menu(shop_id, menu_handle.to_s)
      "m#{m}"
    end

    # For shop metadata
    def for_metadata(shop_id:, vs: Infra::VersionStore.new)
      m = vs.get_metadata(shop_id)
      "md#{m}"
    end

    # Generic: if you only want global catalog
    def for_catalog(shop_id:, vs: Infra::VersionStore.new)
      s = vs.get_shop_catalog(shop_id)
      "s#{s}"
    end
  end
end
