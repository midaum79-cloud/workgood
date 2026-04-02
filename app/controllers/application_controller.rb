class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      session[:return_to] = request.fullpath
      redirect_to login_path, alert: "로그인이 필요합니다."
    end
  end

  def require_plan_for_project!
    return unless logged_in?
    if current_user.project_limit_reached?
      plan = current_user.plan_label
      limit = current_user.plan_limit == Float::INFINITY ? "무제한" : "#{current_user.plan_limit}개"
      redirect_to subscription_path,
        alert: "#{plan} 플랜은 프로젝트 #{limit}까지 가능합니다. 업그레이드하시면 더 많은 현장을 관리할 수 있어요!"
    end
  end
end
