class AddEntrancePasswordsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :common_entrance_password, :string
    add_column :projects, :private_entrance_password, :string
  end
end
