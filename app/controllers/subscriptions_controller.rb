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

  # 토스페이먼츠 결제 검증 (프론트에서 결제 완료 후 호출)
  def verify
    payment_key = params[:paymentKey]
    order_id    = params[:orderId]
    amount      = params[:amount].to_i
    plan        = params[:plan]

    unless %w[standard premium].include?(plan)
      redirect_to subscription_path, alert: "잘못된 플랜입니다." and return
    end

    expected_amount = User::PLAN_PRICES[plan]

    unless amount == expected_amount
      redirect_to subscription_path, alert: "결제 금액이 일치하지 않습니다." and return
    end

    # 토스페이먼츠 결제 승인 API 호출
    confirmation = confirm_toss_payment(payment_key, order_id, amount)

    if confirmation && confirmation["status"] == "DONE"
      # 결제 성공 → 플랜 업그레이드
      current_user.subscription_payments.create!(
        plan: plan,
        amount: expected_amount,
        status: "paid",
        merchant_uid: order_id,
        imp_uid: payment_key,
        paid_at: Time.current,
        expires_at: 1.month.from_now
      )

      current_user.update!(
        subscription_plan: plan,
        billing_started_at: Time.current,
        subscription_expires_at: 1.month.from_now
      )

      redirect_to subscription_path, notice: "🎉 #{User::PLAN_LABELS[plan]} 플랜으로 업그레이드 되었습니다!"
    else
      error_msg = confirmation&.dig("message") || "결제 승인 실패"
      Rails.logger.error "[TossPayments] Confirm failed: #{confirmation}"
      redirect_to subscription_path, alert: "결제 실패: #{error_msg}"
    end
  rescue => e
    Rails.logger.error "[TossPayments] Verify error: #{e.class}: #{e.message}"
    redirect_to subscription_path, alert: "결제 처리 중 오류가 발생했습니다."
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

  private

  # 토스페이먼츠 결제 승인 API
  def confirm_toss_payment(payment_key, order_id, amount)
    secret_key = ENV["TOSS_SECRET_KEY"]
    return nil unless secret_key.present?

    # Base64 인코딩된 시크릿 키 (Basic Auth)
    encoded_key = Base64.strict_encode64("#{secret_key}:")

    response = HTTParty.post(
      "https://api.tosspayments.com/v1/payments/confirm",
      headers: {
        "Authorization" => "Basic #{encoded_key}",
        "Content-Type" => "application/json"
      },
      body: {
        paymentKey: payment_key,
        orderId: order_id,
        amount: amount
      }.to_json
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "[TossPayments] Confirm API error: #{response.code} - #{response.body}"
      response.parsed_response
    end
  end
end
