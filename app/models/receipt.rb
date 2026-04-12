class Receipt < ApplicationRecord
  belongs_to :user
  has_one_attached :image

  validates :receipt_date, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
