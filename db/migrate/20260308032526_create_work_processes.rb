class CreateWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :work_processes do |t|
      t.references :project, null: false, foreign_key: true
      t.string :process_name
      t.date :start_date
      t.date :end_date
      t.string :contractor_name
      t.integer :material_cost
      t.integer :labor_cost
      t.text :memo
      t.string :status

      t.timestamps
    end
  end
end
