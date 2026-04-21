class ApplicationController < ActionController::Base
  before_action :prepare_meta_tags
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
      redirect_to login_path
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

  def prepare_meta_tags
    set_meta_tags(
      site:        "일잘러",
      title:       "시공 현장 스마트 관리 앱",
      separator:   "|",
      description: "시공 일정, 정산, 거래처 관리까지 — 인테리어·건설 현장 소장님을 위한 스마트 관리 앱. 스마트폰 하나로 현장을 통제하세요.",
      keywords:    "현장관리, 시공일정, 인테리어정산, 현장소장, 건설관리, 거래처관리, 스마트현장, 일잘러",
      canonical:   "https://www.workgood.co.kr#{request.path}",
      og: {
        title:       "일잘러 | 시공 현장 스마트 관리 앱",
        description: "시공 일정, 정산, 거래처 관리까지 — 인테리어·건설 현장 소장님을 위한 스마트 관리 앱. 스마트폰 하나로 현장을 통제하세요.",
        url:         "https://www.workgood.co.kr#{request.path}",
        image:       "https://www.workgood.co.kr/og-image.png",
        type:        "website",
        site_name:   "일잘러",
        locale:      "ko_KR"
      },
      twitter: {
        card:        "summary_large_image",
        title:       "일잘러 | 시공 현장 스마트 관리 앱",
        description: "시공 일정, 정산, 거래처 관리까지 — 인테리어·건설 현장 소장님을 위한 스마트 관리 앱.",
        image:       "https://www.workgood.co.kr/og-image.png"
      }
    )
  end
end
