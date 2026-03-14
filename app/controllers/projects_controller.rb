class ProjectsController < ApplicationController
  before_action :require_login
  before_action :require_plan_for_project!, only: %i[new create]
  before_action :set_project, only: %i[show edit update destroy project_calendar]

  def index
    @selected_status = params[:status]
    @view_mode = params[:view_mode].presence || "month"

    @projects =
      case @selected_status
      when "진행중", "예정", "완료"
        current_user.projects.where(status: @selected_status).order(created_at: :desc)
      else
        current_user.projects.order(created_at: :desc)
      end

    @featured_project = @projects.first
    @unread_notifications_count = Notification.where(status: "unread").count

    project_ids = @projects.pluck(:id)
    work_day_scope = WorkDay.includes(work_process: :project)
                            .joins(:work_process)
                            .where(work_processes: { project_id: project_ids })

    today_work_days = work_day_scope.select { |wd| wd.work_date == Time.zone.today }

    @today_work_processes = today_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }

    tomorrow_work_days = work_day_scope.select { |wd| wd.work_date == Time.zone.tomorrow }

    @tomorrow_work_processes = tomorrow_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }

    @ending_soon_processes = []
  end

  def manage
    @selected_status = params[:status]
    @unread_notifications_count = Notification.where(status: "unread").count

    @projects =
      case @selected_status
      when "진행중", "예정", "완료"
        current_user.projects.where(status: @selected_status).order(created_at: :desc)
      else
        current_user.projects.order(created_at: :desc)
      end
  end

  def calendar
    @selected_status = params[:status]
    @view_mode = "month"

    @projects =
      case @selected_status
      when "진행중", "예정", "완료"
        current_user.projects.includes(:work_processes).where(status: @selected_status).order(created_at: :desc)
      else
        current_user.projects.includes(:work_processes).order(created_at: :desc)
      end

    base_date =
      if params[:year].present? && params[:month].present?
        Date.new(params[:year].to_i, params[:month].to_i, 1)
      elsif Time.zone.today.present?
        Time.zone.today
      else
        Time.zone.today
      end

    @calendar_year = base_date.year
    @calendar_month = base_date.month

    if @view_mode == "2weeks"
      calendar_start = base_date.beginning_of_week(:sunday)
      calendar_end = calendar_start + 13.days
      all_days = (calendar_start..calendar_end).to_a
      @calendar_rows = [ all_days.first(7), all_days.last(7) ]
    else
      month_first_day = Date.new(@calendar_year, @calendar_month, 1)
      month_last_day = Date.new(@calendar_year, @calendar_month, -1)
      calendar_start = month_first_day.beginning_of_week(:sunday)
      calendar_end = month_last_day.end_of_week(:sunday)
      all_days = (calendar_start..calendar_end).to_a
      @calendar_rows = all_days.each_slice(7).to_a
    end

    @prev_month = base_date.prev_month
    @next_month = base_date.next_month

    available_days = @calendar_rows.flatten.compact

    @selected_date =
      if params[:selected_date].present?
        begin
          Date.parse(params[:selected_date])
        rescue ArgumentError
          available_days.first || Time.zone.today
        end
      elsif available_days.include?(Time.zone.today)
        Time.zone.today
      else
        available_days.first || Time.zone.today
      end

    project_ids = @projects.pluck(:id)

    work_day_scope = WorkDay.includes(work_process: :project)
                            .joins(:work_process)
                            .where(work_processes: { project_id: project_ids })

    @calendar_bars_by_row = {}
    @calendar_row_heights = {}

    @calendar_rows.each_with_index do |row_days, row_index|
      row_start = row_days.first

      raw_bars = work_day_scope.map do |work_day|
        next unless row_days.include?(work_day.work_date)

        start_index = (work_day.work_date - row_start).to_i

        {
          work_day: work_day,
          work_process: work_day.work_process,
          project: work_day.work_process.project,
          start_index: start_index,
          end_index: start_index,
          span_days: 1
        }
      end.compact

      sorted_bars = raw_bars.sort_by do |bar|
        [
          bar[:start_index],
          bar[:work_process].position || 9999,
          bar[:work_process].id || 0,
          bar[:work_day].id || 0
        ]
      end

      lane_end_indexes = []

      sorted_bars.each do |bar|
        assigned_lane = nil

        lane_end_indexes.each_with_index do |lane_end_index, lane|
          if bar[:start_index] > lane_end_index
            assigned_lane = lane
            break
          end
        end

        assigned_lane ||= lane_end_indexes.length
        lane_end_indexes[assigned_lane] = bar[:end_index]
        bar[:lane] = assigned_lane
      end

      @calendar_bars_by_row[row_index] = sorted_bars
      @calendar_row_heights[row_index] = [ lane_end_indexes.length, 1 ].max * 20
    end

    @calendar_projects = @calendar_bars_by_row.values.flatten.map { |bar| bar[:project] }.uniq

    selected_day_work_days = work_day_scope.select { |wd| wd.work_date == @selected_date }

    @selected_day_work_processes = selected_day_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }
  end

  def project_calendar
    @view_mode = "month"

    base_date =
      if params[:year].present? && params[:month].present?
        Date.new(params[:year].to_i, params[:month].to_i, 1)
      elsif Time.zone.today.present?
        Time.zone.today
      else
        Time.zone.today
      end

    @calendar_year = base_date.year
    @calendar_month = base_date.month

    if @view_mode == "2weeks"
      calendar_start = base_date.beginning_of_week(:sunday)
      calendar_end = calendar_start + 13.days
      all_days = (calendar_start..calendar_end).to_a
      @calendar_rows = [ all_days.first(7), all_days.last(7) ]
    else
      month_first_day = Date.new(@calendar_year, @calendar_month, 1)
      month_last_day = Date.new(@calendar_year, @calendar_month, -1)
      calendar_start = month_first_day.beginning_of_week(:sunday)
      calendar_end = month_last_day.end_of_week(:sunday)
      all_days = (calendar_start..calendar_end).to_a
      @calendar_rows = all_days.each_slice(7).to_a
    end

    @prev_month = base_date.prev_month
    @next_month = base_date.next_month

    available_days = @calendar_rows.flatten.compact

    @selected_date =
      if params[:selected_date].present?
        begin
          Date.parse(params[:selected_date])
        rescue ArgumentError
          available_days.first || Time.zone.today
        end
      elsif available_days.include?(Time.zone.today)
        Time.zone.today
      else
        available_days.first || Time.zone.today
      end

    work_day_scope = WorkDay.includes(work_process: :project)
                            .joins(:work_process)
                            .where(work_processes: { project_id: @project.id })

    @calendar_bars_by_row = {}
    @calendar_row_heights = {}

    @calendar_rows.each_with_index do |row_days, row_index|
      row_start = row_days.first

      raw_bars = work_day_scope.map do |work_day|
        next unless row_days.include?(work_day.work_date)

        start_index = (work_day.work_date - row_start).to_i

        {
          work_day: work_day,
          work_process: work_day.work_process,
          project: work_day.work_process.project,
          start_index: start_index,
          end_index: start_index,
          span_days: 1
        }
      end.compact

      sorted_bars = raw_bars.sort_by do |bar|
        [
          bar[:start_index],
          bar[:work_process].position || 9999,
          bar[:work_process].id || 0,
          bar[:work_day].id || 0
        ]
      end

      lane_end_indexes = []

      sorted_bars.each do |bar|
        assigned_lane = nil

        lane_end_indexes.each_with_index do |lane_end_index, lane|
          if bar[:start_index] > lane_end_index
            assigned_lane = lane
            break
          end
        end

        assigned_lane ||= lane_end_indexes.length
        lane_end_indexes[assigned_lane] = bar[:end_index]
        bar[:lane] = assigned_lane
      end

      @calendar_bars_by_row[row_index] = sorted_bars
      @calendar_row_heights[row_index] = [ lane_end_indexes.length, 1 ].max * 20
    end

    @calendar_projects = [ @project ]
    @projects = [ @project ] # Required for bottom sheet selection

    selected_day_work_days = work_day_scope.select { |wd| wd.work_date == @selected_date }

    @selected_day_work_processes = selected_day_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }
  end

  def show
    @work_processes = @project.ordered_work_processes
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def create
    @project = Project.new(project_params)
    @project.user = current_user
    @project.selected_process_names = params[:project][:selected_process_names]
    @project.custom_process_names_text = params[:project][:custom_process_names_text]

    # If AI JSON is provided, ignore the manual selections to prevent duplicates
    if params[:project][:ai_processes_json].present?
      @project.selected_process_names = []
      @project.custom_process_names_text = ""
    end

    if detail_address_present?
      @project.address = [ @project.address, params[:detail_address] ].reject(&:blank?).join(" ")
    end

    # Auto-assign a unique color based on the number of existing projects (cycles through 10 colors)
    color_palette = %w[blue orange green red purple pink sky yellow teal indigo]
    project_count = current_user.projects.count
    @project.color = color_palette[project_count % color_palette.size]

    # Default status to '예정'
    @project.status ||= "예정"

    if @project.save
      if params[:project][:ai_processes_json].present?
        begin
          ai_items = JSON.parse(params[:project][:ai_processes_json])
          ai_items.each_with_index do |item, idx|
            wp = @project.work_processes.create!(
              process_name: item["raw_text"],
              position: idx
            )
            if item["date"].present?
              WorkDay.create!(
                work_process: wp,
                work_date: item["date"]
              )
            end
          end
          
          # 스탠다드 유저 체험 횟수 차감 기능. 프리미엄은 예외.
          current_user.increment!(:ai_imports_count) if current_user.standard_or_above? && !current_user.premium?

        rescue => e
          Rails.logger.error "AI Processes parsing error: #{e.message}"
        end
      end
      redirect_to @project, notice: "현장이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if detail_address_present?
      merged_address = [ params[:project][:address], params[:detail_address] ].reject(&:blank?).join(" ")
      params[:project][:address] = merged_address
    end

    if @project.update(project_params)
      redirect_to @project, notice: "현장이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "현장이 삭제되었습니다."
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def detail_address_present?
    params[:detail_address].present?
  end

  def project_params
    params.require(:project).permit(
      :project_name,
      :client_name,
      :address,
      :start_date,
      :end_date,
      :status,
      :color,
      :memo,
      :project_type,
      selected_process_names: []
    )
  end
end
