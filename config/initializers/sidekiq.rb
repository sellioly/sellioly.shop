# config/initializers/sidekiq.rb
redis_url = ENV['REDIS_SIDEKIQ_URL'] || ENV['REDIS_URL'] || ENV['REDIS_CABLE_URL'] || 'redis://redis:6379/0'
redis_ns  = ENV.fetch('SIDEKIQ_NAMESPACE', 'sellioly-shop')

Sidekiq.configure_server { |config| config.redis = { url: redis_url, namespace: redis_ns } }
Sidekiq.configure_client { |config| config.redis = { url: redis_url, namespace: redis_ns } }