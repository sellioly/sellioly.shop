class CreateShops < ActiveRecord::Migration[7.1]
  def change
    create_table :shops do |t|
      t.string  :external_store_id, null: false  # Laravel stores.id (ULID)
      t.string  :app_domain,        null: false
      t.string  :status,            null: false, default: "provisioning"
      t.string  :template_path
      t.bigint  :active_shop_theme_id        # FK to shop_themes.id, added index later
      t.string  :active_external_template_id # Laravel templates.id (ULID), denormalized for quick access
      t.datetime :provisioned_at
      t.text    :last_error

      t.timestamps
    end

    add_index :shops, :external_store_id, unique: true
    add_index :shops, :app_domain,        unique: true
    add_index :shops, :status
    add_index :shops, :active_shop_theme_id
  end
end
