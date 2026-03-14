class WorkProcess < ApplicationRecord
  attr_accessor :selected_dates

  belongs_to :project
  has_many :notifications, dependent: :destroy
  has_many :work_days, dependent: :destroy

  after_create :create_start_notification_if_date_present

  def effective_status(reference_date = Date.current)
    return self[:status].presence || "예정" if start_date.blank?

    start_on = start_date.to_date
    end_on = (end_date || start_date).to_date
    target_day = reference_date.to_date

    if target_day < start_on
      "예정"
    elsif target_day > end_on
      "완료"
    else
      "진행중"
    end
  end

  def status
    effective_status(Date.current)
  end

  def stored_status
    self[:status]
  end

  def sync_work_days!(date_strings)
    date_strings = Array(date_strings).reject(&:blank?)
    return if date_strings.empty?

    dates = date_strings.map { |d| Date.parse(d) }.sort

    work_days.destroy_all
    dates.each { |d| work_days.create!(work_date: d) }

    update_columns(
      start_date: dates.first,
      end_date: dates.last
    )

    sync_project_start_date!
  end

  private

  def sync_project_start_date!
    earliest_date = project.work_processes.where.not(start_date: nil).minimum(:start_date)
    return unless earliest_date

    if project.start_date.nil? || earliest_date < project.start_date
      project.update(start_date: earliest_date)
    end
  end

  private

  def create_start_notification_if_date_present
    return if start_date.blank?

    Notification.create(
      title: "공정 시작 예정",
      message: "#{process_name} 공정이 곧 시작됩니다.",
      status: "unread",
      project: project,
      work_process: self
    )
  end
end