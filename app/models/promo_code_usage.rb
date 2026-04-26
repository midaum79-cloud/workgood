class PromoCodeUsage < ApplicationRecord
  belongs_to :user
  belongs_to :promo_code

  validates :user_id, uniqueness: { scope: :promo_code_id, message: "has already used this promo code" }
end
