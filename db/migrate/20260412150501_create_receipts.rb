class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.references :user, null: false, foreign_key: true
      t.date :receipt_date
      t.integer :amount
      t.string :store_name
      t.string :category
      t.text :memo

      t.timestamps
    end
  end
end
