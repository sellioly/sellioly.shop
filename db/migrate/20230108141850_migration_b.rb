class MigrationB < ActiveRecord::Migration[7.0]
  def change
    create_table :stores do |t|
      t.string :app_domain
      t.string :template_path
      t.timestamps
    end
  end
end
