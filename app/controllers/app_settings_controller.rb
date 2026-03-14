class AppSettingsController < ApplicationController
  before_action :require_login

  def index
  end

  def update_profile
    if current_user.update(profile_params)
      redirect_to app_settings_path, notice: "프로필이 업데이트되었습니다."
    else
      flash[:alert] = current_user.errors.full_messages.first
      redirect_to app_settings_path
    end
  end

  def update_password
    unless current_user.authenticate(params[:current_password])
      flash[:alert] = "현재 비밀번호가 올바르지 않습니다."
      return redirect_to app_settings_path
    end

    if params[:new_password] != params[:new_password_confirmation]
      flash[:alert] = "새 비밀번호가 일치하지 않습니다."
      return redirect_to app_settings_path
    end

    if params[:new_password].length < 8
      flash[:alert] = "비밀번호는 8자 이상이어야 합니다."
      return redirect_to app_settings_path
    end

    current_user.update!(
      password: params[:new_password],
      password_confirmation: params[:new_password_confirmation]
    )
    redirect_to app_settings_path, notice: "비밀번호가 변경되었습니다."
  end

  def update_notifications
    current_user.update(notification_params)
    redirect_to app_settings_path, notice: "알림 설정이 저장되었습니다."
  end

  private

  def profile_params
    params.require(:user).permit(:name, :phone)
  end

  def notification_params
    params.require(:user).permit(:evening_alert_enabled, :evening_alert_time)
  end
end
