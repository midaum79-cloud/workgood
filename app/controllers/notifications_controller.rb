class NotificationsController < ApplicationController
  before_action :require_login

  def index
    # 1. 앱(마이페이지/알림함)에 들어왔을 때 자동으로 내일 일정 등 스마트 비서 알림 스캔 후 생성
    Notification.generate_smart_alerts(current_user) if current_user

    @current_tab = params[:tab].presence || "all"

    # 2. 현재 사용자의 프로젝트에 속한 알림만 조회 (보안: 타 사용자 알림 노출 방지)
    user_project_ids = current_user.projects.pluck(:id)
    base_query = Notification.where(project_id: user_project_ids).order(created_at: :desc)

    @notifications = case @current_tab
      when "schedule" then base_query.schedule
      when "finance" then base_query.finance
      when "settings" then []  # 설정 탭은 알림 목록 없음
      else base_query
    end.to_a

    # 3. 알림함 진입(혹은 개별 탭 진입) 시 해당 탭 알림들은 자동 읽음 처리
    unless @current_tab == "settings"
      unread_ids = @notifications.select { |n| n.status == "unread" }.map(&:id)
      Notification.where(id: unread_ids).update_all(status: "read") if unread_ids.any?
    end
  end

  def read
    # 본인 프로젝트의 알림만 읽음 처리 가능
    user_project_ids = current_user.projects.pluck(:id)
    notification = Notification.where(project_id: user_project_ids).find(params[:id])
    notification.update(status: "read")
    redirect_to notifications_path
  end

  def update_settings
    current_user.update(notification_settings_params)
    redirect_to notifications_path(tab: 'settings'), notice: "알림 설정이 저장되었습니다."
  end

  private

  def notification_settings_params
    params.require(:user).permit(
      :morning_alert_enabled, :morning_alert_time,
      :evening_alert_enabled, :evening_alert_time,
      :receivable_alert_enabled, :receivable_alert_days
    )
  end
end