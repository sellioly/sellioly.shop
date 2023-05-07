class Cart < ApplicationRecord
  self.table_name = 'cart'

  def items
    JSON.parse(self[:items]) if self[:items].present?
  end

  def items=(value)
    self[:items] = value.to_json
  end
  
end
