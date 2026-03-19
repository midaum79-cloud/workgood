class Api::WidgetController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login, raise: false

  # POST /api/widget/token
  # 네이티브 앱에서 세션 쿠키로 호출 → 위젯용 토큰 발급
  def token
    user = current_user
    unless user
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end

    # 기존 토큰이 있으면 재사용, 없으면 새로 생성
    existing_token = Rails.cache.read("widget_token_for_user:#{user.id}")
    if existing_token
      token = existing_token
    else
      token = SecureRandom.hex(32)
      # 양방향 매핑: token → user_id, user_id → token
      Rails.cache.write("widget_token:#{token}", user.id)
      Rails.cache.write("widget_token_for_user:#{user.id}", token)
    end

    render json: { token: token }
  end

  # GET /api/widget/schedule
  # 위젯에서 토큰으로 호출 → 오늘/내일 일정 반환
  def schedule
    token = request.headers["Authorization"]&.sub(/^Bearer /, "")
    user = authenticate_widget_token(token)

    unless user
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end

    today = Time.zone.today
    tomorrow = today + 1.day

    projects = user.projects.includes(work_processes: :work_days)

    today_items = []
    tomorrow_items = []

    projects.each do |project|
      project.work_processes.each do |wp|
        wp.work_days.each do |wd|
          item = {
            process: wp.process_name,
            project: project.project_name,
            color: project.theme_color_hex
          }
          today_items << item if wd.work_date == today
          tomorrow_items << item if wd.work_date == tomorrow
        end
      end
    end

    today_items.uniq!
    tomorrow_items.uniq!

    render json: {
      today: today_items,
      tomorrow: tomorrow_items,
      date: today.strftime("%Y-%m-%d"),
      day_name: %w[일 월 화 수 목 금 토][today.wday]
    }
  end

  private

  def authenticate_widget_token(token)
    return nil if token.blank?
    user_id = Rails.cache.read("widget_token:#{token}")
    User.find_by(id: user_id) if user_id
  end
end
