class ProjectsController < ApplicationController
  before_action :require_login
  before_action :require_plan_for_project!, only: %i[new create]
  before_action :set_project, only: %i[show edit update destroy project_calendar]

  def index
    @selected_status = params[:status].presence || '진행중'
    @view_mode = params[:view_mode].presence || "month"

    all_projects = current_user.projects
                               .includes(work_processes: :work_days)
                               .order(created_at: :desc)

    @projects =
      if @selected_status == 'all'
        all_projects
      elsif %w[진행중 예정 완료].include?(@selected_status)
        all_projects.select { |p| p.effective_status == @selected_status }
      else
        all_projects
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

    @today_memo = current_user.daily_memos.find_by(memo_date: Time.zone.today)
    @tomorrow_memo = current_user.daily_memos.find_by(memo_date: Time.zone.tomorrow)
  end

  def manage
    @selected_status = params[:status]
    @unread_notifications_count = Notification.where(status: "unread").count

    all_projects = current_user.projects
                               .includes(work_processes: :work_days)
                               .order(created_at: :desc)

    @projects =
      if %w[진행중 예정 완료].include?(@selected_status)
        all_projects.select { |p| p.effective_status == @selected_status }
      else
        all_projects
      end
  end

  def archive
    all_projects = current_user.projects
      .includes(work_processes: :work_days)
      .where.not(end_date: nil)
      .where("end_date < ?", Date.current)
      .order(created_at: :asc)

    # Group by year then month (based on end_date)
    @grouped = all_projects.group_by { |p| p.end_date.year }
      .sort_by { |year, _| -year } # newest year first
      .map do |year, projects_in_year|
        months = projects_in_year.group_by { |p| p.end_date.month }
          .sort_by { |month, _| month } # month ascending
        [year, months]
      end

    @selected_year = params[:year]&.to_i || @grouped.first&.first || Date.current.year
  end

  def monthly_payments
    @unread_notifications_count = Notification.where(status: "unread").count

    # 기간 파라미터 (기본: 현재 월)
    if params[:start_date].present? && params[:end_date].present?
      @start_date = Date.parse(params[:start_date])
      @end_date = Date.parse(params[:end_date])
    else
      today = Date.current
      @start_date = today.beginning_of_month
      @end_date = today.end_of_month
    end

    @projects = current_user.projects
      .includes(work_processes: :work_days)
      .where("start_date <= ? AND end_date >= ?", @end_date, @start_date)
      .or(current_user.projects.where("start_date >= ? AND start_date <= ?", @start_date, @end_date))
      .order(start_date: :asc)

    @total_estimate = @projects.sum(:estimate_amount).to_i
    @total_deposit = @projects.sum(:deposit_amount).to_i
    @total_outstanding = @total_estimate - @total_deposit

    # 해당 기간 내 작업일 수집 (캘린더 표시용)
    project_ids = @projects.pluck(:id)
    @work_dates = WorkDay.joins(:work_process)
      .where(work_processes: { project_id: project_ids })
      .where(work_date: @start_date..@end_date)
      .pluck(:work_date)
      .uniq
      .sort
  end

  def calendar
    @selected_status = params[:status]
    @view_mode = "month"

    @projects =
      case @selected_status
      when "진행중", "예정", "완료"
        current_user.projects.where(status: @selected_status).order(:start_date)
      else
        current_user.projects.order(:start_date)
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

    month_first_day = Date.new(@calendar_year, @calendar_month, 1)
    month_last_day = Date.new(@calendar_year, @calendar_month, -1)
    calendar_start = month_first_day.beginning_of_week(:sunday)
    calendar_end = month_last_day.end_of_week(:sunday)
    all_days = (calendar_start..calendar_end).to_a
    @calendar_rows = all_days.each_slice(7).to_a

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

    # project_schedules 기반으로 날짜별 프로젝트 조회
    calendar_start = @calendar_rows.flatten.first
    calendar_end = @calendar_rows.flatten.last

    schedules = ProjectSchedule
      .joins(:project)
      .where(projects: { user_id: current_user.id })
      .where(work_date: calendar_start..calendar_end)
      .includes(:project)

    # 상태 필터 적용
    if @selected_status.present? && @selected_status != "all"
      schedules = schedules.where(projects: { status: @selected_status })
    end

    @registered_dates = Set.new(schedules.pluck(:work_date))

    # 날짜별 프로젝트 목록
    @projects_by_date = {}
    schedules.each do |schedule|
      @projects_by_date[schedule.work_date] ||= []
      @projects_by_date[schedule.work_date] << schedule.project unless @projects_by_date[schedule.work_date].include?(schedule.project)
    end

    # 바 레이아웃은 더 이상 사용하지 않음 (날짜별 칩으로 대체)
    @calendar_bars_by_row = {}
    @calendar_row_heights = {}
    @calendar_rows.each_with_index do |row_days, row_index|
      max_count = row_days.map { |d| (@projects_by_date[d] || []).length }.max || 0
      @calendar_row_heights[row_index] = [max_count * 20, 0].max
    end

    @calendar_projects = @projects_by_date.values.flatten.uniq

    # 선택 날짜에 해당하는 프로젝트 목록
    @selected_day_projects = @projects_by_date[@selected_date] || []
  end

  def move_schedule
    project = current_user.projects.find(params[:project_id])
    old_date = Date.parse(params[:old_date])
    new_date = Date.parse(params[:new_date])

    schedule = project.project_schedules.find_by(work_date: old_date)
    if schedule
      # 새 날짜에 이미 같은 프로젝트 스케줄이 있으면 이동 불가
      existing = project.project_schedules.find_by(work_date: new_date)
      if existing
        render json: { success: false, error: "이미 해당 날짜에 등록된 일정입니다." }, status: :unprocessable_entity
        return
      end
      schedule.update!(work_date: new_date)
      project.recalculate_dates_from_schedules!
      render json: { success: true }
    else
      render json: { success: false, error: "스케줄을 찾을 수 없습니다." }, status: :not_found
    end
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def toggle_schedule
    project = current_user.projects.find(params[:project_id])
    date = Date.parse(params[:date])

    schedule = project.project_schedules.find_by(work_date: date)
    if schedule
      schedule.destroy!
      project.recalculate_dates_from_schedules!
      render json: { success: true, action: "removed" }
    else
      project.project_schedules.create!(work_date: date)
      project.recalculate_dates_from_schedules!
      render json: { success: true, action: "added" }
    end
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def project_calendar
    @view_mode = "month"

    # 같은 거래처의 모든 프로젝트 조회
    @client_name = @project.client_name.presence || @project.project_name
    @client_projects = current_user.projects.where(client_name: @client_name).order(:start_date)

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

    month_first_day = Date.new(@calendar_year, @calendar_month, 1)
    month_last_day = Date.new(@calendar_year, @calendar_month, -1)
    calendar_start = month_first_day.beginning_of_week(:sunday)
    calendar_end = month_last_day.end_of_week(:sunday)
    all_days = (calendar_start..calendar_end).to_a
    @calendar_rows = all_days.each_slice(7).to_a

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

    # 등록된 날짜: 각 프로젝트의 start_date~end_date 범위
    @registered_dates = Set.new
    @client_projects.each do |proj|
      next unless proj.start_date && proj.end_date
      (proj.start_date..proj.end_date).each { |d| @registered_dates.add(d) }
    end

    # 프로젝트 단위 바 생성 (start_date ~ end_date)
    @calendar_bars_by_row = {}
    @calendar_row_heights = {}

    @calendar_rows.each_with_index do |row_days, row_index|
      row_start = row_days.first
      row_end = row_days.last

      raw_bars = @client_projects.filter_map do |proj|
        next unless proj.start_date && proj.end_date
        # 이 주(row)와 프로젝트 기간이 겹치는지 확인
        bar_start = [proj.start_date, row_start].max
        bar_end = [proj.end_date, row_end].min
        next if bar_start > bar_end

        start_index = (bar_start - row_start).to_i
        end_index = (bar_end - row_start).to_i
        span_days = end_index - start_index + 1

        {
          project: proj,
          start_index: start_index,
          end_index: end_index,
          span_days: span_days,
          label: proj.project_name.presence || proj.client_name
        }
      end

      sorted_bars = raw_bars.sort_by { |bar| [bar[:start_index], bar[:project].id] }

      lane_end_indexes = []
      sorted_bars.each do |bar|
        assigned_lane = nil
        lane_end_indexes.each_with_index do |lane_end, lane|
          if bar[:start_index] > lane_end
            assigned_lane = lane
            break
          end
        end
        assigned_lane ||= lane_end_indexes.length
        lane_end_indexes[assigned_lane] = bar[:end_index]
        bar[:lane] = assigned_lane
      end

      @calendar_bars_by_row[row_index] = sorted_bars
      @calendar_row_heights[row_index] = [lane_end_indexes.length, 1].max * 22
    end

    @projects = @client_projects

    # 선택 날짜에 해당하는 프로젝트 목록
    @selected_day_projects = @client_projects.select do |proj|
      proj.start_date && proj.end_date &&
        @selected_date >= proj.start_date && @selected_date <= proj.end_date
    end
  end

  def show
    @project = @project.class.includes(work_processes: :work_days).find(@project.id)
    @work_processes = @project.ordered_work_processes
  end

  def new
    @project = Project.new
    @project.client_name = params[:client_name] if params[:client_name].present?
    @project.start_date = params[:start_date] if params[:start_date].present?
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
  def purge_photo
    @project = current_user.projects.find(params[:id])
    photo = @project.photos.find(params[:photo_id])
    photo.purge
    redirect_to edit_project_path(@project), notice: "사진이 삭제되었습니다."
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
      :common_entrance_password,
      :private_entrance_password,
      :start_date,
      :end_date,
      :status,
      :color,
      :memo,
      :project_type,
      :estimate_amount,
      :deposit_amount,
      :payment_status,
      :worker_names,
      :work_description,
      selected_process_names: [],
      photos: []
    )
  end
end
