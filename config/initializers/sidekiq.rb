# inside config/initializers/sidekiq.rb

Sidekiq.configure_server do |config|
  config.redis = { url:  ENV['REDIS_CABLE_URL'] }
end
Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_CABLE_URL']}
end
