class ShopDomain < ApplicationRecord
  belongs_to :shop

  enum ssl_status: {
    none:         "none",
    provisioning: "provisioning",
    active:       "active",
    failed:       "failed"
  }
end
