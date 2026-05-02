class AddClientPhoneToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :client_phone, :string
  end
end
