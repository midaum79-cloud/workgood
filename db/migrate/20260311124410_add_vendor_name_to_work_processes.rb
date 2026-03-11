class AddVendorNameToWorkProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :work_processes, :vendor_name, :string
  end
end
