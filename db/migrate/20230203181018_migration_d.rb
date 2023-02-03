class MigrationD < ActiveRecord::Migration[7.0]
  def change
    change_column :stores, :template_id, :bigint
    change_column :stores, :shop_id, :bigint
  end
end
