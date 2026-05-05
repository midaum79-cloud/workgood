class WebPushService
  def self.send_notification(subscription, title:, body:, path: "/", icon: "/icon-192.png")
    return if VAPID_PUBLIC_KEY.blank? || VAPID_PRIVATE_KEY.blank?

    payload = {
      title: title,
      options: {
        body: body,
        icon: icon,
        badge: "/icon-192.png",
        data: { path: path },
        vibrate: [ 200, 100, 200 ],
        requireInteraction: false
      }
    }.to_json

    begin
      Webpush.payload_send(
        message: payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: {
          public_key: VAPID_PUBLIC_KEY,
          private_key: VAPID_PRIVATE_KEY,
          subject: VAPID_EMAIL
        },
        ssl_timeout: 5,
        open_timeout: 5,
        read_timeout: 5
      )
    rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription => e
      Rails.logger.info "[WebPush] Removing invalid subscription #{subscription.id}: #{e.message}"
      subscription.destroy
    rescue => e
      Rails.logger.error "[WebPush] Failed to send to subscription #{subscription.id}: #{e.class}: #{e.message}"
    end
  end

  # Send notification to all subscriptions for a user
  def self.notify_user(user, title:, body:, path: "/")
    # 1. PWA Web Push 전송
    user.web_push_subscriptions.find_each do |sub|
      send_notification(sub, title: title, body: body, path: path)
    end

    # 2. OneSignal Native Push 전송
    send_onesignal_notification(user, title: title, body: body, path: path)
  end

  def self.send_onesignal_notification(user, title:, body:, path: "/")
    app_id = "c988f2df-d594-45a2-afa5-36791e1351af"
    api_key = ENV['ONESIGNAL_REST_API_KEY']
    return if api_key.blank?

    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse("https://api.onesignal.com/notifications")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Basic #{api_key}"
    request["accept"] = "application/json"
    
    request.body = JSON.dump({
      "app_id" => app_id,
      "include_aliases" => { "external_id" => [user.id.to_s] },
      "target_channel" => "push",
      "headings" => { "en" => title, "ko" => title },
      "contents" => { "en" => body, "ko" => body },
      "data" => { "path" => path }
    })

    req_options = { use_ssl: uri.scheme == "https" }
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      Rails.logger.info "[OneSignal] Sent to user #{user.id}: #{response.code} #{response.body}"
    rescue => e
      Rails.logger.error "[OneSignal] Failed to send to user #{user.id}: #{e.class} #{e.message}"
    end
  end

  # Send daily work process reminder to all users
  def self.send_daily_reminders
    tomorrow = Date.tomorrow

    User.includes(projects: { work_processes: :work_days }).find_each do |user|
      tomorrow_processes = []

      user.projects.each do |project|
        project.work_processes.each do |wp|
          if wp.work_days.any? { |wd| wd.work_date == tomorrow }
            tomorrow_processes << { project: project.project_name, process: wp.process_name }
          end
        end
      end

      next if tomorrow_processes.empty?
      next if user.web_push_subscriptions.empty?

      if tomorrow_processes.size == 1
        tp = tomorrow_processes.first
        body = "#{tp[:project]} - #{tp[:process]}"
      else
        body = tomorrow_processes.map { |tp| "#{tp[:project]}: #{tp[:process]}" }.first(3).join(", ")
        body += " 외 #{tomorrow_processes.size - 3}건" if tomorrow_processes.size > 3
      end

      notify_user(user, title: "📅 내일 공정 알림", body: body, path: "/projects/calendar")
    end
  end
end
