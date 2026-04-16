class AddGenerationsCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :biz_card_generations_count, :integer, default: 0
    add_column :users, :bank_card_generations_count, :integer, default: 0
  end
end
