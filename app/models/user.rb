class User < ApplicationRecord
  has_secure_password validations: false
  validates :password, length: { minimum: 8 }, confirmation: true, if: -> { password.present? }
  validates :password_confirmation, presence: true, if: -> { password.present? }

  has_many :projects, dependent: :nullify
  has_many :subscription_payments, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :daily_memos, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :vendors, dependent: :destroy
  has_many :receipts, dependent: :destroy
  has_many :promo_code_usages, dependent: :destroy
  has_many :consultations, dependent: :destroy
  has_many :used_promo_codes, through: :promo_code_usages, source: :promo_code

  has_secure_token :document_share_token

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_save :downcase_email

  PLAN_LIMITS  = { "free" => 200, "standard" => 500, "premium" => Float::INFINITY }.freeze
  PLAN_PRICES  = { "free" => 0, "standard" => 4_400, "premium" => 9_900 }.freeze
  PLAN_LABELS  = { "free" => "무료", "standard" => "스탠다드", "premium" => "프리미엄" }.freeze

  # ⚠️ 테스트 기간: 모든 사용자 프리미엄 처리 (요금제 완성 후 false로 변경)
  TESTING_PERIOD = false

  # ── Google OAuth ──────────────────────────────────────────────────────
  def self.find_or_create_from_omniauth(auth)
    email = auth.info.email&.downcase&.strip
    uid   = auth.uid
    provider = auth.provider

    # Apple은 첫 로그인 이후 email을 안 줄 수 있으므로 uid로 먼저 찾기
    user = find_by(provider: provider, uid: uid) if uid.present?
    user ||= find_by(email: email) if email.present?
    user ||= new

    user.tap do |u|
      u.provider = provider
      u.uid      = uid
      u.email    = email if email.present? && (u.email.blank? || !u.persisted?)
      # Apple은 email 없이 올 수 있으므로 더미 이메일 생성
      u.email  ||= "#{provider}_#{uid}@oauth.workgood.co.kr"
      # Apple name 처리: first_name + last_name 조합
      apple_name = if auth.info.first_name.present? || auth.info.last_name.present?
        [ auth.info.first_name, auth.info.last_name ].compact.join(" ")
      end
      u.name = apple_name.presence || auth.info.name.presence || u.name.presence || u.email.split("@").first

      # OAuth users get a random secure password they never need to use
      unless u.persisted?
        generated_password = SecureRandom.hex(24)
        u.password = generated_password
        u.password_confirmation = generated_password
      end
      u.save!
    end
  rescue => e
    Rails.logger.error "OmniAuth user creation failed: #{e.message} | #{e.backtrace&.first(3)&.join(' | ')}"
    nil
  end

  def subscription_plan
    return "premium" if is_admin? || TESTING_PERIOD

    plan = self[:subscription_plan].presence || "free"
    # 체험 만료 체크: 유료 플랜 + 만료일 지남 + 결제(빌링키) 없음 → 무료로 다운그레이드
    if plan != "free" && subscription_expires_at.present? && subscription_expires_at < Time.current && billing_key.blank?
      # RevenueCat 구독인지 실시간 확인 시도
      synced_plan = sync_revenuecat_subscription
      if synced_plan
        return synced_plan
      else
        # RevenueCat에서도 구독이 없거나 만료된 경우 무료로 다운그레이드
        update_columns(subscription_plan: "free", subscription_expires_at: nil)
        return "free"
      end
    end
    plan
  end

  def sync_revenuecat_subscription
    # RevenueCat API 키 확인 (Google/Apple 키 중 하나 사용)
    rc_key = ENV["REVENUECAT_GOOGLE_API_KEY"] || ENV["REVENUECAT_APPLE_API_KEY"]
    return nil if rc_key.blank?

    require "net/http"
    require "json"

    begin
      uri = URI("https://api.revenuecat.com/v1/subscribers/#{id}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{rc_key}"
      req["Accept"] = "application/json"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 3 # 3초 타임아웃으로 웹 요청 지연 최소화
        http.read_timeout = 3
        http.request(req)
      end

      if res.code == "200"
        data = JSON.parse(res.body)
        entitlements = data.dig("subscriber", "entitlements") || {}

        # premium과 standard 중 활성화된 최고 플랜 선택
        active_plan = nil
        latest_expires_at = nil

        %w[premium standard].each do |plan_name|
          entitlement = entitlements[plan_name]
          next if entitlement.blank?

          expires_date_str = entitlement["expires_date"]
          is_active = expires_date_str.nil? || Time.parse(expires_date_str) > Time.current

          if is_active
            expires_at = expires_date_str.present? ? Time.parse(expires_date_str) : nil
            
            # 최고 플랜 우선 (premium > standard)
            if active_plan.nil? || (active_plan == "standard" && plan_name == "premium")
              active_plan = plan_name
              latest_expires_at = expires_at
            end
          end
        end

        if active_plan
          # 갱신 완료: DB 업데이트
          update_columns(
            subscription_plan: active_plan,
            subscription_expires_at: latest_expires_at
          )
          return active_plan
        end
      end
    rescue => e
      Rails.logger.error "[RevenueCat Sync] Failed to sync subscription for User #{id}: #{e.message}"
    end

    nil
  end

  def trial?
    subscription_plan != "free" && billing_key.blank? && subscription_expires_at.present?
  end

  def trial_days_remaining
    return 0 unless trial?
    [ (subscription_expires_at.to_date - Date.current).to_i, 0 ].max
  end

  def plan_limit
    return Float::INFINITY if is_admin?
    PLAN_LIMITS[subscription_plan] || 1
  end

  def project_limit_reached?
    return false if plan_limit == Float::INFINITY
    projects.count >= plan_limit
  end

  def can_use_ai_import?
    true
  end

  def ai_imports_remaining
    "무제한"
  end

  # ── 기능 권한 (모든 요금제에 100% 무료 제공) ──────────────────────────
  def can_view_stats?
    true
  end

  def can_view_vendor_analysis?
    true
  end

  def can_manage_receivables?
    true
  end

  def can_export_excel?
    true
  end

  def can_use_tax_report?
    true
  end

  def can_use_widget?
    true
  end

  def can_use_auto_alert?
    true
  end

  def can_use_daily_diary?
    true
  end

  def premium?
    subscription_plan == "premium" || is_admin?
  end

  def free?
    subscription_plan == "free" && !is_admin?
  end

  def standard_or_above?
    %w[standard premium].include?(subscription_plan) || is_admin?
  end

  def is_admin?
    self[:is_admin] || email == "midaum79@gmail.com"
  end

  def plan_label
    return "관리자(프리미엄)" if is_admin?
    PLAN_LABELS[subscription_plan] || "무료"
  end

  def plan_price
    PLAN_PRICES[subscription_plan] || 0
  end

  private

  def downcase_email
    self.email = email.downcase.strip if email.present?
  end
end
