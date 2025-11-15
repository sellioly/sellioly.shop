class DropOldTables < ActiveRecord::Migration[7.0]
  def change
    # Only drop if it exists; safe in dev
    drop_table :stores, if_exists: true
    drop_table :template, if_exists: true
    drop_table :cart, if_exists: true
  end
end
