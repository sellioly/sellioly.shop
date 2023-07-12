require_relative "boot"

require "rails/all"

require_relative "../performance/shopify/shop_filter"
require_relative "../performance/shopify/json_filter"
require_relative "../performance/shopify/money_filter"
require_relative "../performance/shopify/weight_filter"
require_relative "../performance/shopify/tag_filter"
require_relative "../performance/shopify/section_tag"
require_relative "../performance/shopify/render_tag"
require_relative "../performance/shopify/snippet_tag"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sellioly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.active_job.queue_adapter = :sidekiq

    @liquid_instance.register_filter(JsonFilter)
    @liquid_instance.register_filter(MoneyFilter)
    @liquid_instance.register_filter(WeightFilter)
    @liquid_instance.register_filter(ShopFilter)
    @liquid_instance.register_filter(TagFilter)
    @liquid_instance.register_tag('section', SectionTag)
    @liquid_instance.register_tag('render', RenderTag)
    @liquid_instance.register_tag('snippet', SnippetTag)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
