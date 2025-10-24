# frozen_string_literal: true

# Minimal in-memory LRU cache for compiled Liquid templates when Rails.cache is
# unavailable. Thread-safe via a Mutex.
module Theme
  class TemplateCache
    Entry = Struct.new(:key, :value)

    def initialize(max: (ENV["LIQUID_CACHE_SIZE"] || 512).to_i)
      @max   = [max, 32].max
      @store = {}
      @order = []
      @lock  = Mutex.new
    end

    def fetch(key)
      @lock.synchronize do
        if @store.key?(key)
          touch(key)
          return @store[key]
        end
      end
      val = yield
      @lock.synchronize { write!(key, val) }
      val
    end

    private

    def touch(key)
      @order.delete(key)
      @order << key
    end

    def write!(key, val)
      @store[key] = val
      touch(key)
      evict! if @order.size > @max
    end

    def evict!
      k = @order.shift
      @store.delete(k)
    end
  end
end
