require 'redis'
module StoreHelper
  @redis = Redis.new(url: ENV['REDIS_CABLE_URL'])

  def redis_set(app_domain, shop_id, key, value)
    @redis.set("domain:#{app_domain}-shop:#{shop_id}.#{key}", value)
  end

  def redis_get(app_domain, shop_id, key)
    @redis.get("domain:#{app_domain}-shop:#{shop_id}.#{key}")
  end

  def redis_del(app_domain, shop_id, key)
    @redis.del("domain:#{app_domain}-shop:#{shop_id}.#{key}")
  end
end
