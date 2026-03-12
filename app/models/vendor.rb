class Vendor < ApplicationRecord
  validates :name, presence: true
  scope :ordered, -> { order(name: :asc) }

  SPECIALTIES = %w[철거 목공 전기 타일 도배 설비 샤시 바닥 필름 가구 조명 도장 청소 기타].freeze
end
