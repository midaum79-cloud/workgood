class AddEstimateAndWorkFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :estimate_amount, :integer
    add_column :projects, :deposit_amount, :integer
    add_column :projects, :payment_status, :string
    add_column :projects, :worker_names, :text
    add_column :projects, :work_description, :text
  end
end
