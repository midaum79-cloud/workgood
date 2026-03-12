class SubscriptionsController < ApplicationController
  before_action :require_login

  def index
    @current_plan = current_user.subscription_plan
    @project_count = current_user.projects.count
    @plan_limit = current_user.plan_limit
  end

  def update
    plan = params[:plan]
    allowed_plans = %w[free standard premium]

    unless allowed_plans.include?(plan)
      redirect_to subscription_path, alert: "잘못된 요금제입니다." and return
    end

    # TODO: 실제 결제 연동 (포트원/나이스) 후 처리
    # 지금은 즉시 플랜 변경 (테스트용)
    if current_user.update(subscription_plan: plan, subscription_expires_at: 1.month.from_now)
      redirect_to subscription_path, notice: "요금제가 #{User::PLAN_LABELS[plan]}(으)로 변경되었습니다."
    else
      redirect_to subscription_path, alert: "변경에 실패했습니다."
    end
  end
end
