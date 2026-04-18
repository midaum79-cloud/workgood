class AddImageDataToReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :receipts, :image_data, :binary
    add_column :receipts, :image_content_type, :string
  end
end
