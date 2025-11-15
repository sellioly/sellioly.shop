class Shop < ApplicationRecord
  has_many :shop_domains, dependent: :destroy
  has_many :shop_themes, dependent: :destroy

  belongs_to :active_shop_theme,
             class_name: "ShopTheme",
             optional: true

  enum status: {
    provisioning: "provisioning",
    ready:        "ready",
    failed:       "failed",
    suspended:    "suspended",
    archived:     "archived"
  }
end
