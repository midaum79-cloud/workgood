class PromoCode < ApplicationRecord
  has_many :promo_code_usages, dependent: :destroy
  has_many :users, through: :promo_code_usages

  validates :code, presence: true, uniqueness: true
  validates :reward_days, presence: true, numericality: { greater_than: 0 }
end
