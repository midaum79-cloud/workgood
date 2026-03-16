class CreateDailyMemos < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_memos do |t|
      t.references :user, null: false, foreign_key: true
      t.date :memo_date
      t.text :content

      t.timestamps
    end
  end
end
