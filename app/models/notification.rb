class Notification < ApplicationRecord
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
          title: title,
          message: message,
          project_id: project.id,
          category: "schedule",
          status: "unread",
          link_url: "/projects/#{project.id}"
        )
      end
    end
  end
end