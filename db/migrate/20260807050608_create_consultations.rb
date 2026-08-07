class CreateConsultations < ActiveRecord::Migration[8.1]
  def change
    create_table :consultations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :customer_name
      t.string :contact_number
      t.string :address
      t.date :consultation_date
      t.string :consultation_time
      t.text :memo

      t.timestamps
    end
  end
end
