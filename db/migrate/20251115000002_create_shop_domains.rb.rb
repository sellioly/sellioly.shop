class CreateShopDomains < ActiveRecord::Migration[7.1]
  def change
    create_table :shop_domains do |t|
      t.references :shop, null: false, foreign_key: true
      t.string     :hostname,  null: false
      t.boolean    :is_primary, default: false, null: false
      t.string     :ssl_status, default: "none", null: false  # none, provisioning, active, failed

      t.timestamps
    end

    add_index :shop_domains, :hostname, unique: true
    add_index :shop_domains, :is_primary
    add_index :shop_domains, :ssl_status
  end
end
