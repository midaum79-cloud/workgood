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
end