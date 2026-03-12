class CreateVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.string :name
      t.string :contact_name
      t.string :phone
      t.string :specialty
      t.text :memo

      t.timestamps
    end
  end
end
