class AddFieldsToVendors < ActiveRecord::Migration[8.1]
  def change
    add_column :vendors, :business_number, :string
    add_column :vendors, :address, :string
    add_column :vendors, :vendor_type, :string
  end
end
