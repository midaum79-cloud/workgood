class CreateWorkDays < ActiveRecord::Migration[8.1]
  def change
    create_table :work_days do |t|
      t.references :work_process, null: false, foreign_key: true
      t.date :work_date

      t.timestamps
    end
  end
end
