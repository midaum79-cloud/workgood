class WorkDaysController < ApplicationController
  def toggle
    work_process = WorkProcess.find(params[:work_process_id])
    work_date = Date.parse(params[:work_date])

    existing_work_day = work_process.work_days.find_by(work_date: work_date)

    if existing_work_day.present?
      existing_work_day.destroy
      selected = false
    else
      work_process.work_days.create!(work_date: work_date)
      selected = true
    end

    # Sync start_date / end_date on the parent work_process
    all_dates = work_process.work_days.order(:work_date).pluck(:work_date)
    work_process.update_columns(
      start_date: all_dates.first,
      end_date:   all_dates.last
    )

    # Also sync project start date if earliest process date changed
    if all_dates.any?
      earliest = work_process.project.work_processes.where.not(start_date: nil).minimum(:start_date)
      if earliest && (work_process.project.start_date.nil? || earliest < work_process.project.start_date)
        work_process.project.update_columns(start_date: earliest)
      end
    end

    render json: {
      success: true,
      selected: selected,
      work_date: work_date
    }
  rescue ArgumentError
    render json: {
      success: false,
      error: "잘못된 날짜입니다."
    }, status: :unprocessable_entity
  end

  def move
    work_day = WorkDay.find(params[:work_day_id])
    new_date = Date.parse(params[:new_date])

    work_day.update!(work_date: new_date)

    # Recalculate parent work_process start/end dates
    work_process = work_day.work_process
    all_dates = work_process.work_days.order(:work_date).pluck(:work_date)
    work_process.update_columns(
      start_date: all_dates.first,
      end_date: all_dates.last
    )

    render json: { success: true, new_date: new_date }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "작업일을 찾을 수 없습니다." }, status: :not_found
  rescue ArgumentError
    render json: { success: false, error: "잘못된 날짜입니다." }, status: :unprocessable_entity
  end
end