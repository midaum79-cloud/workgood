class AddDescriptionToWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :work_processes, :description, :text
  end
end
