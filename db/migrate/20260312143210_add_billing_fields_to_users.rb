class AddBillingFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :billing_key, :string
    add_column :users, :customer_uid, :string
    add_column :users, :billing_started_at, :datetime
  end
end
