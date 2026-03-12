class ProcessTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  scope :ordered, -> { order(position: :asc, id: :asc) }

  DEFAULT_NAMES = %w[철거 확장 설비 샤시 목공 전기 타일 필름 도배 바닥 가구 조명 기타공사 청소].freeze

  def self.seed_defaults!
    DEFAULT_NAMES.each_with_index do |name, idx|
      find_or_create_by!(name: name) do |t|
        t.position = idx + 1
        t.is_default = true
      end
    end
  end
end
