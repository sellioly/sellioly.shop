class ShopTheme < ApplicationRecord
  belongs_to :shop

  enum status: {
    installing: "installing",
    active:     "active",
    disabled:   "disabled",
    failed:     "failed"
  }
end
