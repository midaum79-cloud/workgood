namespace :push do
  desc "Send daily push notifications for tomorrow's work processes"
  task daily_reminder: :environment do
    Rails.logger.info "[PushReminder] Starting daily reminder..."
    WebPushService.send_daily_reminders
    Rails.logger.info "[PushReminder] Done."
  end
end
