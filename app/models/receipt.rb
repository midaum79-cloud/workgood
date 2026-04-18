class Receipt < ApplicationRecord
  belongs_to :user
  # has_one_attached :image  # R2 호환 이슈로 비활성화 — DB 직접 저장 방식 사용

  validates :receipt_date, presence: true
end
