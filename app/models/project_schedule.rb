class ProjectSchedule < ApplicationRecord
  belongs_to :project

  validates :work_date, presence: true
  validates :work_date, uniqueness: { scope: :project_id, message: "이미 등록된 날짜입니다" }

  scope :ordered, -> { order(:work_date) }
  scope :for_date, ->(date) { where(work_date: date) }
  scope :for_range, ->(start_date, end_date) { where(work_date: start_date..end_date) }
end
