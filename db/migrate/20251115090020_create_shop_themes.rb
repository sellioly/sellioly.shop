class CreateShopThemes < ActiveRecord::Migration[7.0]
  def change
    create_table :shop_themes do |t|
      t.references :shop, null: false, foreign_key: true
      t.string  :external_template_id        # Laravel templates.id (ULID)

      t.string  :theme_handle,  null: false     # "hyper"
      t.string  :theme_version, null: false     # "1.0.0"
      t.string  :root_path,     null: false     # "/storage/shops/123/themes/hyper-1.0.0"

      t.string  :status,        null: false, default: "installing" # installing, active, disabled, failed
      t.jsonb   :settings,      null: false, default: {}  # theme settings per shop

      t.datetime :installed_at
      t.datetime :uninstalled_at

      t.string  :external_theme_purchase_id   # optional back-reference to Laravel theme_purchases.id

      t.timestamps
    end

    add_index :shop_themes, [:shop_id, :status]
    add_index :shop_themes, [:theme_handle, :theme_version]
    add_index :shop_themes, :external_theme_purchase_id
  end
end
