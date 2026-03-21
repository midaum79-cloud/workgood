class Project < ApplicationRecord
  belongs_to :user, optional: true
  has_many :work_processes, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many_attached :photos

  attr_accessor :selected_process_names, :custom_process_names_text, :ai_processes_json

  validates :start_date, presence: { message: "공사 시작일을 입력해 주세요." }
  validates :end_date,   presence: { message: "공사 종료일을 입력해 주세요." }

  after_create :create_selected_processes

  def ordered_work_processes
    work_processes.sort_by do |process|
      [
        process.position || 9999,
        process.start_date || Date.new(2100, 1, 1),
        process.id || 0
      ]
    end
  end

  # Date-aware project status: computed from start_date / end_date
  def effective_status(today = Date.current)
    return self[:status].presence || "예정" if start_date.blank?

    s = start_date.to_date
    e = (end_date || start_date).to_date

    if today < s
      "예정"
    elsif today > e
      "완료"
    else
      "진행중"
    end
  end

  # Override status to always return the date-computed version
  def status
    effective_status(Date.current)
  end

  def total_work_processes_count
    work_processes.count
  end

  def completed_work_processes_count
    ordered_work_processes.count { |p| p.effective_status(Date.current) == "완료" }
  end

  def in_progress_work_processes_count
    ordered_work_processes.count { |p| p.effective_status(Date.current) == "진행중" }
  end

  def scheduled_work_processes_count
    ordered_work_processes.count { |p| p.effective_status(Date.current) == "예정" }
  end

  def progress_percentage
    total = total_work_processes_count
    return 0 if total.zero?

    ((completed_work_processes_count.to_f / total) * 100).round
  end

  def current_work_process
    ordered_work_processes.find do |process|
      process.effective_status(Date.current) == "진행중"
    end
  end

  def next_work_process
    current = current_work_process
    ordered = ordered_work_processes

    return ordered.find { |process| process.effective_status(Date.current) == "예정" } unless current.present?

    current_index = ordered.index(current)
    return nil unless current_index

    ordered[(current_index + 1)..]&.find do |process|
      process.effective_status(Date.current) != "완료"
    end
  end

  def default_process_names
    case project_type
    when "commercial"
      [
        "철거",
        "설비",
        "경량",
        "목공",
        "전기",
        "냉난방",
        "유리공사",
        "금속공사",
        "자동문",
        "페인트",
        "도배",
        "바닥",
        "가구",
        "간판",
        "사인",
        "조명",
        "청소"
      ]
    else
      [
        "철거",
        "확장",
        "샤시",
        "목공",
        "전기",
        "에어컨",
        "타일",
        "도기",
        "필름",
        "도배",
        "바닥",
        "돔천장",
        "탄성코트",
        "가구",
        "조명",
        "청소"
      ]
    end
  end

  def theme_color_hex
    case color
    when "blue"   then "#2563eb"
    when "green"  then "#16a34a"
    when "orange" then "#ea580c"
    when "red"    then "#dc2626"
    when "purple" then "#7c3aed"
    else "#b8860b" # gold/default
    end
  end

  private

  def create_selected_processes
    return if work_processes.exists?

    selected_names = Array(selected_process_names).reject(&:blank?)

    custom_names =
      custom_process_names_text.to_s
                               .split(/[\n,]/)
                               .map(&:strip)
                               .reject(&:blank?)

    final_names = (selected_names + custom_names).uniq

    # 아무 공정도 선택하지 않았으면 생성 안 함 (AI 등록의 경우도 해당)
    return if final_names.empty?

    final_names.each_with_index do |name, index|
      work_processes.create(
        process_name: name,
        status: "예정",
        start_date: nil,
        end_date: nil,
        position: index + 1
      )
    end
  end
end
