class Cart < ApplicationRecord
  self.table_name = 'cart'

  def items
    JSON.parse(self[:items]) if self[:items].present?
  end
end
