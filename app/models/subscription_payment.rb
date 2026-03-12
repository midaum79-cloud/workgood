class SubscriptionPayment < ApplicationRecord
  belongs_to :user

  validates :plan, presence: true
  validates :amount, presence: true
  validates :merchant_uid, presence: true, uniqueness: true

  scope :successful, -> { where(status: "paid") }
  scope :recent, -> { order(created_at: :desc) }

  def paid?
    status == "paid"
  end
end
