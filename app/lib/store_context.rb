# app/lib/shop_context.rb
# Holds the current shop id for this request (thread-safe via RequestStore)
module StoreContext
  def self.store_id
    RequestStore.store[:store_id]
  end

  def self.store_id=(val)
    RequestStore.store[:store_id] = val
  end

  def self.clear!
    RequestStore.store[:store_id] = nil
  end
end
