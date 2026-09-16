class AddDetailAddressToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :detail_address, :string
  end
end
