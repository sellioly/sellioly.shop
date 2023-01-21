class MigrationC < ActiveRecord::Migration[7.0]
  def change
    add_column :stores, :template_id, :integer
    add_column :stores, :shop_id, :integer
  end
end
