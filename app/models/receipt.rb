class Receipt < ApplicationRecord
  belongs_to :user
  has_one_attached :image

  validates :receipt_date, presence: true
end
