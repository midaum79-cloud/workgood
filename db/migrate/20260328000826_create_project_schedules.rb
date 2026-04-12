class CreateProjectSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :project_schedules do |t|
      t.references :project, null: false, foreign_key: true
      t.date :work_date, null: false

      t.timestamps
    end
    add_index :project_schedules, [ :project_id, :work_date ], unique: true
    add_index :project_schedules, :work_date
  end
end
