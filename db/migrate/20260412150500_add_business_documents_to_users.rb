class AddBusinessDocumentsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :document_share_token, :string
    add_index :users, :document_share_token, unique: true
    add_column :users, :business_card_b64, :text
    add_column :users, :business_registration_b64, :text
    add_column :users, :bankbook_copy_b64, :text
    add_column :users, :business_bankbook_copy_b64, :text
  end
end
