class AddSettlementFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :material_cost, :integer, default: 0
    add_column :projects, :material_details, :text
    add_column :projects, :labor_cost, :integer, default: 0
    add_column :projects, :labor_details, :text
    add_column :projects, :equipment_cost, :integer, default: 0
    add_column :projects, :equipment_details, :text
  end
end
