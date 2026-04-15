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

  has_secure_token :document_share_token

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_save :downcase_email

  PLAN_LIMITS  = { "free" => 10, "standard" => 20, "premium" => Float::INFINITY }.freeze
  PLAN_PRICES  = { "free" => 0, "standard" => 4_900, "premium" => 9_900 }.freeze
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
        u.subscription_plan = "premium"
        u.subscription_expires_at = 1.month.from_now
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
    return "premium" if TESTING_PERIOD

    plan = self[:subscription_plan].presence || "free"
    # 체험 만료 체크: 유료 플랜 + 만료일 지남 + 결제(빌링키) 없음 → 무료로 다운그레이드
    if plan != "free" && subscription_expires_at.present? && subscription_expires_at < Time.current && billing_key.blank?
      update_columns(subscription_plan: "free")
      return "free"
    end
    plan
  end

  def trial?
    subscription_plan != "free" && billing_key.blank? && subscription_expires_at.present?
  end

  def trial_days_remaining
    return 0 unless trial?
    [ (subscription_expires_at.to_date - Date.current).to_i, 0 ].max
  end

  def plan_limit
    PLAN_LIMITS[subscription_plan] || 1
  end

  def project_limit_reached?
    projects.count >= plan_limit
  end

  def can_use_ai_import?
    return true if premium?
    standard_or_above? && (ai_imports_count || 0) < 10
  end

  def ai_imports_remaining
    return "무제한" if premium?
    return 0 if free?
    [ 10 - (ai_imports_count || 0), 0 ].max
  end

  # ── 기능 권한 (플랜별 차별화) ──────────────────────────────────────
  def can_view_stats?
    standard_or_above?
  end

  def can_view_vendor_analysis?
    standard_or_above?
  end

  def can_manage_receivables?
    standard_or_above?
  end

  def can_export_excel?
    premium?
  end

  def can_use_tax_report?
    premium?
  end

  def can_use_widget?
    premium?
  end

  def can_use_auto_alert?
    premium?
  end

  def can_use_daily_diary?
    standard_or_above?
  end

  def premium?
    subscription_plan == "premium"
  end

  def free?
    subscription_plan == "free"
  end

  def standard_or_above?
    %w[standard premium].include?(subscription_plan)
  end

  def plan_label
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
