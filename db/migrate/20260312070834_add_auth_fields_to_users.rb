class AddAuthFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email, :string
    add_index :users, :email, unique: true
    add_column :users, :subscription_plan, :string
    add_column :users, :subscription_expires_at, :datetime
  end
end
