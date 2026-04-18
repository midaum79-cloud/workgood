class Notification < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :project, optional: true
  belongs_to :work_process, optional: true

  scope :unread, -> { where(status: "unread") }
  scope :schedule, -> { where(category: "schedule") }
  scope :finance, -> { where(category: "finance") }
  scope :general, -> { where(category: "general") }

  def mark_as_read
    update(status: "read")
  end

  def self.generate_smart_alerts(user)
    tomorrow = Time.zone.tomorrow

    # 1. 내일 일정(노쇼 방지 및 주소/비번 자동 발송) 스캔 및 생성
    user.projects.includes(:project_schedules).each do |project|
      if project.project_schedules.any? { |s| s.work_date == tomorrow }
        title = "📅 내일(#{tomorrow.strftime('%m/%d')}) 시공 일정 안내"

        # 중복 생성 방지
        next if Notification.exists?(
          project_id: project.id,
          category: "schedule",
          title: title
        )

        message = "내일 #{project.client_name.presence || project.project_name} 현장 시공이 예정되어 있습니다.\n\n[현장 정보]\n- 주소: #{project.address.presence || '미등록'}\n- 공동현관: #{project.common_entrance_password.presence || '미등록'}\n- 세대현관: #{project.private_entrance_password.presence || '미등록'}\n\n*일정에 차질이 없도록 미리 준비해 주세요."

        Notification.create(
          user_id: user.id,
          title: title,
          message: message,
          project_id: project.id,
          category: "schedule",
          status: "unread",
          link_url: "/projects/#{project.id}"
        )
      end
    end

    # 2. 프리미엄 이벤트 만료 알림 (7일 전 + 당일)
    if user.trial? && user.subscription_expires_at.present?
      expires_date = user.subscription_expires_at.to_date
      days_left = (expires_date - Date.current).to_i

      # 7일 전 사전 알림
      if days_left == 7
        warn_title = "⏰ 프리미엄 무료 체험이 7일 후 종료됩니다"
        unless Notification.exists?(user_id: user.id, title: warn_title)
          Notification.create(
            user_id: user.id,
            title: warn_title,
            message: "#{expires_date.strftime('%m월 %d일')}에 프리미엄 무료 체험이 종료됩니다.\n\n프리미엄 요금제를 구독하시면 현장 무제한 등록, 세금 관리, 돈 관리 등 모든 기능을 계속 이용하실 수 있습니다.\n\n👉 구독 페이지에서 확인해 보세요!",
            category: "general",
            status: "unread",
            link_url: "/subscription"
          )
        end
      end

      # 3일 전 리마인더
      if days_left == 3
        remind_title = "🔔 프리미엄 무료 체험 종료 3일 전!"
        unless Notification.exists?(user_id: user.id, title: remind_title)
          Notification.create(
            user_id: user.id,
            title: remind_title,
            message: "프리미엄 체험이 #{expires_date.strftime('%m월 %d일')}에 종료됩니다.\n\n지금 구독하시면 기존 데이터와 기능이 그대로 유지됩니다!\n일잘러 프리미엄으로 현장 관리를 더 스마트하게 하세요 💪",
            category: "general",
            status: "unread",
            link_url: "/subscription"
          )
        end
      end

      # 만료 당일 알림
      if days_left == 0
        expire_title = "🚨 프리미엄 무료 체험이 오늘 종료됩니다"
        unless Notification.exists?(user_id: user.id, title: expire_title)
          Notification.create(
            user_id: user.id,
            title: expire_title,
            message: "오늘부터 무료 플랜으로 전환됩니다.\n\n무료 플랜에서는 현장 등록 10개, 기본 기능만 이용 가능합니다.\n\n프리미엄 구독으로 모든 기능을 계속 사용하세요!\n🏗️ 현장 무제한 · 💰 돈 관리 · 🧾 세금 관리",
            category: "general",
            status: "unread",
            link_url: "/subscription"
          )
        end
      end
    end
  end
end
