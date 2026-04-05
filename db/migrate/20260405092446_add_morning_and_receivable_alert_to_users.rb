class AddMorningAndReceivableAlertToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :morning_alert_enabled, :boolean, default: false
    add_column :users, :morning_alert_time, :string, default: "07:00"
    add_column :users, :receivable_alert_enabled, :boolean, default: false
    add_column :users, :receivable_alert_days, :integer, default: 7
  end
end
