class SeedDefaultProcessTemplates < ActiveRecord::Migration[8.0]
  def up
    # 기존 기본 템플릿 삭제 후 재생성
    ProcessTemplate.where(is_default: true).delete_all

    # 주거공간 기본 공정
    residential = %w[철거 확장 샤시 목공 전기 에어컨 타일 도기 필름 도배 바닥 돔천장 탄성코트 가구 조명 청소]
    residential.each_with_index do |name, idx|
      ProcessTemplate.create!(
        name: name,
        project_type: "residential",
        position: idx + 1,
        is_default: true
      )
    end

    # 상업공간 기본 공정
    commercial = %w[철거 설비 경량 목공 전기 냉난방 유리공사 금속공사 자동문 페인트 도배 바닥 가구 간판 사인 조명 청소]
    commercial.each_with_index do |name, idx|
      ProcessTemplate.create!(
        name: name,
        project_type: "commercial",
        position: idx + 1,
        is_default: true
      )
    end
  end

  def down
    ProcessTemplate.where(is_default: true).delete_all
  end
end
