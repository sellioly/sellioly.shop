class MigrationE < ActiveRecord::Migration[7.0]
  def change
    add_column :cart, :subtotal, :float
  end
end
