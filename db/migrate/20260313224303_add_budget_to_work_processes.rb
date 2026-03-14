class AddBudgetToWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :work_processes, :budget, :integer, default: 0
  end
end
