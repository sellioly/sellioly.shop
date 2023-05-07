class CreateCart < ActiveRecord::Migration[7.0]
  def change
    create_table :cart do |t|
      t.string :cart_id
      t.text :items

      t.timestamps
    end
  end
end
