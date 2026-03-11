class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.string :title
      t.text :message
      t.string :status
      t.references :project, null: false, foreign_key: true
      t.references :work_process, null: false, foreign_key: true

      t.timestamps
    end
  end
end
