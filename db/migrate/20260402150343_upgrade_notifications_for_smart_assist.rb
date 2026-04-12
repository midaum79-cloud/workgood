class UpgradeNotificationsForSmartAssist < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :category, :string, default: "general"
    add_column :notifications, :link_url, :string

    change_column_null :notifications, :project_id, true
    change_column_null :notifications, :work_process_id, true
  end
end
