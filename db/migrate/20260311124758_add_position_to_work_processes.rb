class AddPositionToWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :work_processes, :position, :integer
  end
end
