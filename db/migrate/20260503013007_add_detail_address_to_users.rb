class AddDetailAddressToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :detail_address, :string
  end
end
