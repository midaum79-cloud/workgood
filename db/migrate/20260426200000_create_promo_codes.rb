class CreatePromoCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.integer :reward_days, null: false, default: 30
      t.integer :max_uses
      t.integer :current_uses, default: 0
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :promo_codes, :code, unique: true
  end
end
