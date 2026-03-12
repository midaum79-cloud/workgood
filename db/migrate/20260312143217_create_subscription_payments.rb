class CreateSubscriptionPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_payments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :plan
      t.integer :amount
      t.string :status
      t.string :merchant_uid
      t.string :imp_uid
      t.string :billing_key
      t.datetime :paid_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
