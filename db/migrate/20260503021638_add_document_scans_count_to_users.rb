class AddDocumentScansCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :document_scans_count, :integer
  end
end
