# frozen_string_literal: true

# Fragment cache store used by the {% cache %} tag.
# - Tries Redis (REDIS_URL or REDIS_CABLE_URL) first
# - Falls back to in-memory LRU for safety
class FragmentCacheStore
  def initialize
    @redis = begin
      require 'redis'
      url = ENV['REDIS_URL'] || ENV['REDIS_CABLE_URL']
      Redis.new(url: url) if url
    rescue StandardError
      nil
    end
    @mem = MemLRU.new
  end

  def fetch(key, ttl: nil)
    if @redis
      val = @redis.get(key)
      return val unless val.nil?
      val = yield
      set(key, val, ttl: ttl)
      val
    else
      @mem.fetch(key, ttl: ttl) { yield }
    end
  end

  def set(key, val, ttl: nil)
    if @redis
      ttl.to_i > 0 ? @redis.setex(key, ttl.to_i, val) : @redis.set(key, val)
    else
      @mem.write(key, val, ttl: ttl)
    end
  end

  # minimal in-memory LRU with TTL
  class MemLRU
    def initialize(max: (ENV['FRAGMENT_CACHE_SIZE'] || 256).to_i)
      @max = [max, 64].max
      @hash = {}
      @order = []
      @lock = Mutex.new
    end
    def fetch(key, ttl: nil)
      @lock.synchronize do
        if (e = @hash[key]) && !expired?(e)
          touch(key)
          return e[:val]
        end
      end
      val = yield
      write(key, val, ttl: ttl)
      val
    end
    def write(key, val, ttl: nil)
      @lock.synchronize do
        @hash[key] = { val: val, exp: ttl ? (Time.now.to_i + ttl.to_i) : nil }
        touch(key)
        evict! if @order.size > @max
      end
    end
    private
    def touch(key)
      @order.delete(key)
      @order << key
    end
    def expired?(e)
      e[:exp] && e[:exp] <= Time.now.to_i
    end
    def evict!
      k = @order.shift
      @hash.delete(k)
    end
  end
end
