# frozen_string_literal: true

require_relative "../../performance/shopify/shop_filter"
require_relative "../../performance/shopify/json_filter"
require_relative "../../performance/shopify/money_filter"
require_relative "../../performance/shopify/weight_filter"
require_relative "../../performance/shopify/tag_filter"
require_relative "../../performance/shopify/t_filter"

# Filters
Liquid::Template.register_filter(JsonFilter)
Liquid::Template.register_filter(MoneyFilter)
Liquid::Template.register_filter(WeightFilter)
Liquid::Template.register_filter(ShopFilter)
Liquid::Template.register_filter(TagFilter)
Liquid::Template.register_filter(TFilter)

# Tags — wrap in to_prepare so dev reloads don’t double-register
Rails.application.config.to_prepare do
  Liquid::Template.register_tag('section',  ::Liquid::Tags::SectionTag)
  Liquid::Template.register_tag('render',   ::Liquid::Tags::RenderTag)
  Liquid::Template.register_tag('snippet',  ::Liquid::Tags::SnippetTag)
  Liquid::Template.register_tag('cache',    ::Liquid::Tags::CacheTag)
  Liquid::Template.register_tag('paginate', ::Liquid::Tags::PaginateTag)
end