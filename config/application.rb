require_relative "boot"

require "rails/all"
require 'sidekiq'


require_relative "../app/helpers/performance/shopify/shop_filter"
require_relative "../app/helpers/performance/shopify/json_filter"
require_relative "../app/helpers/performance/shopify/money_filter"
require_relative "../app/helpers/performance/shopify/weight_filter"
require_relative "../app/helpers/performance/shopify/tag_filter"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sellioly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.active_job.queue_adapter = :sidekiq

    Liquid::Template.register_filter(JsonFilter)
    Liquid::Template.register_filter(MoneyFilter)
    Liquid::Template.register_filter(WeightFilter)
    Liquid::Template.register_filter(ShopFilter)
    Liquid::Template.register_filter(TagFilter)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
