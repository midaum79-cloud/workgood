class AddUserIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :user_id, :bigint
  end
end
