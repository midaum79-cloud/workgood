class AddNotificationSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :evening_alert_enabled, :boolean
    add_column :users, :evening_alert_time, :string
  end
end
