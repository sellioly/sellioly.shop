class Cart < ApplicationRecord
  self.table_name = 'cart'

  attribute :items, :json
  
end
