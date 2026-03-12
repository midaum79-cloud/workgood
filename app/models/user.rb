class User < ApplicationRecord
  has_secure_password

  has_many :projects, dependent: :nullify

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_save :downcase_email

  PLAN_LIMITS = { "free" => 1, "standard" => 3, "premium" => Float::INFINITY }.freeze
  PLAN_PRICES = { "free" => 0, "standard" => 4_900, "premium" => 9_900 }.freeze
  PLAN_LABELS = { "free" => "무료", "standard" => "스탠다드", "premium" => "프리미엄" }.freeze

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
