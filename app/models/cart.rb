class Cart < ApplicationRecord
  self.table_name = 'cart'

  serialize :items, JSON

end
