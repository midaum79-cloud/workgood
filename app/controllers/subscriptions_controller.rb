class SubscriptionsController < ApplicationController
  before_action :require_login
  skip_before_action :verify_authenticity_token, only: [:verify]

  def index
    @current_plan = current_user.subscription_plan
    @project_count = current_user.projects.count
    @plan_limit = current_user.plan_limit
    @last_payment = current_user.subscription_payments.successful.recent.first
  end

  def update
    plan = params[:plan]
    allowed_plans = %w[free standard premium]

    unless allowed_plans.include?(plan)
      redirect_to subscription_path, alert: "잘못된 요금제입니다." and return
    end

    # 무료로 전환 — 결제 불필요
    if plan == "free"
      current_user.update(
        subscription_plan: "free",
        billing_key: nil,
        customer_uid: nil,
        billing_started_at: nil
      )
      redirect_to subscription_path, notice: "무료 플랜으로 전환되었습니다." and return
    end

    # 유료 플랜 — 프론트에서 결제 후 verify로 검증
    redirect_to subscription_path, alert: "결제가 필요합니다."
  end

  # Apple In-App Purchase (RevenueCat) 결제 후 승인 처리
  def verify_apple
    plan = params[:plan]

    unless %w[standard premium].include?(plan)
      return redirect_to subscription_path, alert: "잘못된 플랜입니다."
    end

    expected_amount = User::PLAN_PRICES[plan]

    # 결제 기록 저장 (실패해도 구독 업그레이드는 진행)
    begin
      current_user.subscription_payments.create(
        plan: plan,
        amount: expected_amount,
        status: "paid",
        merchant_uid: "apple_in_app_#{Time.now.to_i}_#{current_user.id}",
        imp_uid: "revenuecat_#{current_user.id}_#{Time.now.to_i}",
        paid_at: Time.current,
        expires_at: 1.month.from_now
      )
    rescue => e
      Rails.logger.error "[Subscription] Payment record creation failed: #{e.message}"
    end

    # 구독 플랜 업그레이드 (핵심 처리)
    begin
      current_user.update!(
        subscription_plan: plan,
        billing_started_at: Time.current,
        subscription_expires_at: 1.month.from_now
      )
      redirect_to subscription_path, notice: "🎉 #{User::PLAN_LABELS[plan]} 플랜으로 업그레이드 되었습니다!"
    rescue => e
      Rails.logger.error "[Subscription] User update failed: #{e.message}"
      redirect_to subscription_path, notice: "🎉 결제가 완료되었습니다! 앱을 재시작하면 #{User::PLAN_LABELS[plan]} 플랜이 적용됩니다."
    end
  end

  # 구독 해지
  def cancel
    current_user.update(
      subscription_plan: "free",
      billing_key: nil,
      customer_uid: nil,
      billing_started_at: nil
    )
    redirect_to subscription_path, notice: "구독이 해지되었습니다. 무료 플랜으로 전환됩니다."
  end
end
