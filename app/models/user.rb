class User < ApplicationRecord
  has_secure_password validations: false
  validates :password, length: { minimum: 8 }, confirmation: true, if: -> { password.present? }
  validates :password_confirmation, presence: true, if: -> { password.present? }

  has_many :projects, dependent: :nullify
  has_many :subscription_payments, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :daily_memos, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_save :downcase_email

  PLAN_LIMITS  = { "free" => 1, "standard" => 3, "premium" => Float::INFINITY }.freeze
  PLAN_PRICES  = { "free" => 0, "standard" => 4_900, "premium" => 9_900 }.freeze
  PLAN_LABELS  = { "free" => "무료", "standard" => "스탠다드", "premium" => "프리미엄" }.freeze

  # ── Google OAuth ──────────────────────────────────────────────────────
  def self.find_or_create_from_omniauth(auth)
    find_or_initialize_by(email: auth.info.email.downcase).tap do |user|
      user.provider = auth.provider
      user.uid      = auth.uid
      user.name     = auth.info.name.presence || auth.info.email.split("@").first
      user.subscription_plan ||= "standard"
      user.subscription_expires_at ||= 1.month.from_now
      # OAuth users get a random secure password they never need to use
      unless user.persisted?
        generated_password = SecureRandom.hex(24)
        user.password = generated_password
        user.password_confirmation = generated_password
      end
      user.save!
    end
  rescue => e
    Rails.logger.error "OmniAuth user creation failed: #{e.message}"
    nil
  end

  def subscription_plan
    "premium" # 테스트를 위해 임시로 모든 사용자를 프리미엄으로 취급
    # plan = self[:subscription_plan].presence || "free"
    # # 체험 만료 체크: 유료 플랜 + 만료일 지남 + 결제(빌링키) 없음 → 무료로 다운그레이드
    # if plan != "free" && subscription_expires_at.present? && subscription_expires_at < Time.current && billing_key.blank?
    #   update_columns(subscription_plan: "free")
    #   return "free"
    # end
    # plan
  end

  def trial?
    subscription_plan != "free" && billing_key.blank? && subscription_expires_at.present?
  end

  def trial_days_remaining
    return 0 unless trial?
    [(subscription_expires_at.to_date - Date.current).to_i, 0].max
  end

  def plan_limit
    PLAN_LIMITS[subscription_plan] || 1
  end

  def project_limit_reached?
    projects.count >= plan_limit
  end

  def can_use_ai_import?
    return true if premium?
    standard_or_above? && (ai_imports_count || 0) < 3
  end

  def ai_imports_remaining
    return "무제한" if premium?
    return 0 if free?
    [3 - (ai_imports_count || 0), 0].max
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
