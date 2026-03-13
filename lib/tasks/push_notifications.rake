namespace :push_notifications do
  desc "Send evening alerts for tomorrow's work processes to premium users"
  task evening_alert: :environment do
    puts "[#{Time.current}] Starting evening_alert push notifications..."

    # 1. Get tomorrow's date
    tomorrow = Date.tomorrow

    # 2. Find premium users who have evening alerts enabled
    # We will assume a method or direct query.
    users = User.where(subscription_plan: "premium", evening_alert_enabled: true)
                .where.not(evening_alert_time: nil)

    # For now, we are sending to all enabled premium users at this scheduled time (e.g. 6 PM)
    # If we wanted exact times per user, we would filter by `evening_alert_time` matching current hour.

    users.find_each do |user|
      next if user.web_push_subscriptions.empty?

      # Find tomorrow's work processes for this user's projects
      tomorrow_processes = WorkProcess.joins(:project, :work_days)
                                      .where(projects: { user_id: user.id })
                                      .where(work_days: { work_date: tomorrow })
                                      .distinct

      next if tomorrow_processes.empty?

      # Build notification body
      body_text = "내일 현장 안내\n"
      tomorrow_processes.each do |wp|
        body_text += "· #{wp.process_name} — #{wp.project.project_name}\n"
      end

      # Send to all subscriptions for this user
      user.web_push_subscriptions.find_each do |sub|
        begin
          message = {
            title: "일머리 알림",
            options: {
              body: body_text,
              icon: "/icon.png",
              data: {
                path: "/projects/calendar"
              }
            }
          }

          Webpush.payload_send(
            message: JSON.generate(message),
            endpoint: sub.endpoint,
            p256dh: sub.p256dh,
            auth: sub.auth,
            vapid: {
              subject: "mailto:support@ilmeori.com",
              public_key: ENV["VAPID_PUBLIC_KEY"],
              private_key: ENV["VAPID_PRIVATE_KEY"]
            }
          )
        rescue Webpush::InvalidSubscription => e
          puts "Invalid subscription for user #{user.id}, cleaning up."
          sub.destroy
        rescue => e
          puts "Failed to send push to user #{user.id}: #{e.message}"
        end
      end
    end

    puts "[#{Time.current}] Finished evening_alert push notifications."
  end
end
