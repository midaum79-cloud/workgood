class SubscriptionsController < ApplicationController
  before_action :require_login
  skip_before_action :verify_authenticity_token, only: [:webhook, :verify]

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

  # PortOne 결제 검증 (프론트에서 결제 완료 후 호출)
  def verify
    payment_id = params[:paymentId]   # PortOne에서 반환한 결제 ID
    plan       = params[:plan]

    unless %w[standard premium].include?(plan)
      render json: { success: false, message: "잘못된 플랜" }, status: :bad_request and return
    end

    expected_amount = User::PLAN_PRICES[plan]

    # PortOne V2 API로 결제 검증
    verification = verify_portone_payment(payment_id)

    if verification && verification["status"] == "PAID" && verification["amount"]["total"] == expected_amount
      # 결제 성공 → 플랜 업그레이드
      payment = current_user.subscription_payments.create!(
        plan: plan,
        amount: expected_amount,
        status: "paid",
        merchant_uid: verification["merchantId"] || payment_id,
        imp_uid: payment_id,
        billing_key: params[:billingKey],
        paid_at: Time.current,
        expires_at: 1.month.from_now
      )

      current_user.update!(
        subscription_plan: plan,
        billing_key: params[:billingKey],
        customer_uid: "customer_#{current_user.id}",
        billing_started_at: Time.current,
        subscription_expires_at: 1.month.from_now
      )

      render json: { success: true, message: "#{User::PLAN_LABELS[plan]} 플랜으로 업그레이드 되었습니다!" }
    else
      render json: { success: false, message: "결제 검증 실패. 고객센터에 문의해주세요." }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "[Payment] Verify error: #{e.message}"
    render json: { success: false, message: "결제 처리 중 오류가 발생했습니다." }, status: :internal_server_error
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

  def webhook
    # PortOne webhook endpoint
    render plain: "OK"
  end

  private

  def verify_portone_payment(payment_id)
    api_secret = ENV["PORTONE_API_SECRET"]
    return nil unless api_secret.present?

    response = HTTParty.get(
      "https://api.portone.io/payments/#{payment_id}",
      headers: {
        "Authorization" => "PortOne #{api_secret}",
        "Content-Type" => "application/json"
      }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "[PortOne] Verify failed: #{response.code} - #{response.body}"
      nil
    end
  end
end
