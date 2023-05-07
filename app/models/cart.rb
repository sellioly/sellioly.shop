class Cart < ApplicationRecord
  self.table_name = 'cart'

  serialize :preferences, JSON

end
