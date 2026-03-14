class ProcessTemplate < ApplicationRecord
  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_type }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :residential, -> { where(project_type: "residential").ordered }
  scope :commercial,  -> { where(project_type: "commercial").ordered }

  RESIDENTIAL_DEFAULTS = %w[철거 확장 샤시 목공 전기 에어컨 타일 도기 필름 도배 바닥 돔천장 탄성코트 가구 조명 청소].freeze
  COMMERCIAL_DEFAULTS  = %w[철거 설비 경량 목공 전기 냉난방 유리공사 금속공사 자동문 페인트 도배 바닥 가구 간판 사인 조명 청소].freeze

  def self.seed_defaults!
    # Residential
    RESIDENTIAL_DEFAULTS.each_with_index do |name, idx|
      find_or_create_by!(name: name, project_type: "residential") do |t|
        t.position   = idx + 1
        t.is_default = true
      end
    end
    # Commercial
    COMMERCIAL_DEFAULTS.each_with_index do |name, idx|
      find_or_create_by!(name: name, project_type: "commercial") do |t|
        t.position   = idx + 1
        t.is_default = true
      end
    end
  end
end
