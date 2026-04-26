class Admin::BaseController < ApplicationController
  before_action :require_login
  before_action :require_admin

  private

  def require_admin
    unless current_user&.is_admin?
      redirect_to root_path, alert: "접근 권한이 없습니다."
    end
  end
end
