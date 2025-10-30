# inside config/initializers/sidekiq.rb
redis_url = ENV['REDIS_SIDEKIQ_URL'] || ENV['REDIS_URL'] || ENV['REDIS_CABLE_URL'] || 'redis://redis:6379/1'

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end