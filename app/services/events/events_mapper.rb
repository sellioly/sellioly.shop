# app/services/events/events_mapper.rb
# frozen_string_literal: true

module Events
  module EventsMapper
    module_function

    # normalized event shape → perform bumps on VersionStore
    def bump!(vs:, shop_id:, entity:, operation:, handle:)
      case entity
      when "product"
        vs.bump_product(shop_id, handle) if handle.to_s.present?
        vs.bump_shop_catalog(shop_id)
        vs.bump_collection(shop_id, "all")
      when "collection"
        vs.bump_collection(shop_id, (handle.presence || "all"))
        vs.bump_shop_catalog(shop_id)
      when "menu"
        vs.bump_menu(shop_id, handle) if handle.to_s.present?
      when "metadata", "shop"
        vs.bump_metadata(shop_id)
      else
        # ignore unknown entities
      end
    end
  end
end
