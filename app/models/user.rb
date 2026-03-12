class User < ApplicationRecord
  has_secure_password validations: false
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  has_many :projects, dependent: :nullify
  has_many :subscription_payments, dependent: :destroy

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
      user.subscription_plan ||= "free"
      # OAuth users get a random secure password they never need to use
      user.password = SecureRandom.hex(24) unless user.persisted?
      user.save!
    end
  rescue => e
    Rails.logger.error "OmniAuth user creation failed: #{e.message}"
    nil
  end

  def subscription_plan
    self[:subscription_plan].presence || "free"
  end

  def plan_limit
    PLAN_LIMITS[subscription_plan] || 1
  end

  def project_limit_reached?
    projects.count >= plan_limit
  end

  def premium?
    subscription_plan == "premium"
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
