class ProjectsController < ApplicationController
  before_action :require_login
  before_action :require_plan_for_project!, only: %i[new create]
  before_action :set_project, only: %i[show edit update destroy project_calendar project_calendar_panel]
  before_action :require_premium_for_money!, only: %i[monthly_payments]

  def index
    @selected_status = params[:status].presence || '예정'
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
    @unread_notifications_count = current_user.notifications.where(status: "unread").count

    project_ids = @projects.pluck(:id)
    work_day_scope = WorkDay.includes(work_process: :project)
                            .joins(:work_process)
                            .where(work_processes: { project_id: project_ids })

    today_work_days = work_day_scope.select { |wd| wd.work_date == Time.zone.today }

    @today_work_processes = today_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }

    @today_schedules = ProjectSchedule
      .where(project_id: project_ids, work_date: Time.zone.today)
      .includes(:project)

    tomorrow_work_days = work_day_scope.select { |wd| wd.work_date == Time.zone.tomorrow }

    @tomorrow_work_processes = tomorrow_work_days
      .map(&:work_process)
      .uniq
      .sort_by { |process| [ process.position || 9999, process.id || 0 ] }

    @tomorrow_schedules = ProjectSchedule
      .where(project_id: project_ids, work_date: Time.zone.tomorrow)
      .includes(:project)

    @ending_soon_processes = []

    @today_memo = current_user.daily_memos.find_by(memo_date: Time.zone.today)
    @tomorrow_memo = current_user.daily_memos.find_by(memo_date: Time.zone.tomorrow)
  end

  def manage
    @selected_status = params[:status]
    @unread_notifications_count = current_user.notifications.where(status: "unread").count

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
    @unread_notifications_count = current_user.notifications.where(status: "unread").count

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
      .where("projects.start_date <= ? AND projects.end_date >= ?", @end_date, @start_date)
      .or(current_user.projects.where("projects.start_date >= ? AND projects.start_date <= ?", @start_date, @end_date))
      .order("projects.start_date ASC")

    @total_estimate = @projects.sum { |p| p.estimate_amount.to_i }
    @total_collected = @projects.sum { |p| p.payment_status == "완납" ? p.estimate_amount.to_i : (p.deposit_amount.to_i + p.mid_payment.to_i) }
    @total_outstanding = @projects.sum { |p| p.payment_status == "완납" ? 0 : [p.estimate_amount.to_i - (p.deposit_amount.to_i + p.mid_payment.to_i), 0].max }

    # 미수금 현장 (완납 제외)
    @outstanding_projects = @projects.reject { |p| p.payment_status == "완납" }
                                     .select { |p| p.estimate_amount.to_i > (p.deposit_amount.to_i + p.mid_payment.to_i) }

    # 거래처별 매출 분석
    @vendor_stats = @projects.group_by(&:client_name).map do |client_name, projs|
      {
        name: client_name.presence || "미지정",
        count: projs.size,
        estimate: projs.sum { |p| p.estimate_amount.to_i },
        collected: projs.sum { |p| p.payment_status == "완납" ? p.estimate_amount.to_i : (p.deposit_amount.to_i + p.mid_payment.to_i) },
        outstanding: projs.sum { |p| p.payment_status == "완납" ? 0 : [p.estimate_amount.to_i - p.deposit_amount.to_i - p.mid_payment.to_i, 0].max }
      }
    end.sort_by { |v| -v[:estimate] }

    # 해당 기간 내 작업일 수집 (캘린더 표시용)
    project_ids = @projects.pluck(:id)
    @work_dates = ProjectSchedule
      .where(project_id: project_ids)
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

    # 3패널 캐러셀용: 이전달/다음달 데이터
    @prev_calendar = build_month_data(@prev_month, current_user.id, @selected_status)
    @next_calendar = build_month_data(@next_month, current_user.id, @selected_status)
  end

  # AJAX: 특정 월의 캘린더 그리드 HTML 조각만 반환 (3패널 캐러셀용)
  def calendar_panel
    @selected_status = params[:status]
    base_date = Date.new(params[:year].to_i, params[:month].to_i, 1)

    @calendar_year = base_date.year
    @calendar_month = base_date.month

    month_first_day = Date.new(@calendar_year, @calendar_month, 1)
    month_last_day = Date.new(@calendar_year, @calendar_month, -1)
    calendar_start = month_first_day.beginning_of_week(:sunday)
    calendar_end = month_last_day.end_of_week(:sunday)
    all_days = (calendar_start..calendar_end).to_a
    @calendar_rows = all_days.each_slice(7).to_a

    @selected_date = params[:selected_date].present? ? Date.parse(params[:selected_date]) : Time.zone.today

    schedules = ProjectSchedule
      .joins(:project)
      .where(projects: { user_id: current_user.id })
      .where(work_date: calendar_start..calendar_end)
      .includes(:project)

    if @selected_status.present? && @selected_status != "all"
      schedules = schedules.where(projects: { status: @selected_status })
    end

    @projects_by_date = {}
    schedules.each do |schedule|
      @projects_by_date[schedule.work_date] ||= []
      @projects_by_date[schedule.work_date] << schedule.project unless @projects_by_date[schedule.work_date].include?(schedule.project)
    end

    render partial: 'projects/calendar_grid', layout: false
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

    # project_schedules 기반으로 날짜별 프로젝트 조회
    calendar_start = @calendar_rows.flatten.first
    calendar_end = @calendar_rows.flatten.last

    client_project_ids = @client_projects.pluck(:id)
    schedules = ProjectSchedule
      .where(project_id: client_project_ids)
      .where(work_date: calendar_start..calendar_end)
      .includes(:project)

    @registered_dates = Set.new(schedules.pluck(:work_date))

    # 날짜별 프로젝트 목록
    @projects_by_date = {}
    schedules.each do |schedule|
      @projects_by_date[schedule.work_date] ||= []
      @projects_by_date[schedule.work_date] << schedule.project unless @projects_by_date[schedule.work_date].include?(schedule.project)
    end

    @calendar_row_heights = {}
    @calendar_rows.each_with_index do |row_days, row_index|
      max_count = row_days.map { |d| (@projects_by_date[d] || []).length }.max || 0
      @calendar_row_heights[row_index] = [max_count * 20, 0].max
    end

    @projects = @client_projects

    # 선택 날짜에 해당하는 프로젝트 목록
    @selected_day_projects = @projects_by_date[@selected_date] || []

    # 3패널 캐러셀용: 이전달/다음달 데이터
    @prev_calendar = build_month_data_for_project(@prev_month, client_project_ids)
    @next_calendar = build_month_data_for_project(@next_month, client_project_ids)
  end

  # AJAX: 프로젝트 캘린더 패널 HTML 조각 반환
  def project_calendar_panel
    @client_name = @project.client_name.presence || @project.project_name
    @client_projects = current_user.projects.where(client_name: @client_name).order(:start_date)

    base_date = Date.new(params[:year].to_i, params[:month].to_i, 1)

    @calendar_year = base_date.year
    @calendar_month = base_date.month

    month_first_day = Date.new(@calendar_year, @calendar_month, 1)
    month_last_day = Date.new(@calendar_year, @calendar_month, -1)
    calendar_start = month_first_day.beginning_of_week(:sunday)
    calendar_end = month_last_day.end_of_week(:sunday)
    all_days = (calendar_start..calendar_end).to_a
    @calendar_rows = all_days.each_slice(7).to_a

    @selected_date = params[:selected_date].present? ? Date.parse(params[:selected_date]) : Time.zone.today

    client_project_ids = @client_projects.pluck(:id)
    schedules = ProjectSchedule
      .where(project_id: client_project_ids)
      .where(work_date: calendar_start..calendar_end)
      .includes(:project)

    @projects_by_date = {}
    schedules.each do |schedule|
      @projects_by_date[schedule.work_date] ||= []
      @projects_by_date[schedule.work_date] << schedule.project unless @projects_by_date[schedule.work_date].include?(schedule.project)
    end

    render partial: 'projects/calendar_grid', locals: { cell_min_height: '75px' }, layout: false
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
    # 사진 파일은 저장 후 별도 첨부 (create 시 동시 처리하면 500 에러 발생)
    photo_files = params.dig(:project, :photos)&.reject { |f| f.blank? || !f.respond_to?(:read) } || []

    @project = Project.new(project_params.except(:photos))
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
      # 사진이 있는 경우 저장 후 첨부
      @project.photos.attach(photo_files) if photo_files.any?

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

  def quick_create
    color_palette = %w[blue orange green red purple pink sky yellow teal indigo]
    project_count  = current_user.projects.count

    @project = current_user.projects.new(
      client_name:    params[:client_name],
      project_name:   params[:client_name],
      start_date:     params[:date],
      end_date:       params[:date],
      payment_status: "미결제",
      color:          color_palette[project_count % color_palette.size]
    )
    if @project.save
      render json: { success: true }
    else
      render json: { success: false, error: @project.errors.full_messages.join(", ") }
    end
  end

  def update
    if detail_address_present?
      merged_address = [ params[:project][:address], params[:detail_address] ].reject(&:blank?).join(" ")
      params[:project][:address] = merged_address
    end

    # 사진 파일은 별도 처리 (빈 파일 필드가 오류 일으키지 않도록)
    photo_files = params.dig(:project, :photos)&.reject { |f| f.blank? || !f.respond_to?(:read) } || []
    base_params = project_params.except(:photos)

    if @project.update(base_params)
      # 새 사진이 실제로 업로드된 경우에만 첨부
      @project.photos.attach(photo_files) if photo_files.any?
      redirect_to @project, notice: "현장이 수정되었습니다."
    else
      Rails.logger.error "[Project Update Failed] #{@project.errors.full_messages.inspect}"
      flash.now[:alert] = @project.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end
  def purge_photo
    @project = current_user.projects.find(params[:id])
    photo = @project.photos.find(params[:photo_id])
    photo.purge
    redirect_to edit_project_path(@project), notice: "사진이 삭제되었습니다."
  end

  def update_payment
    @project = current_user.projects.find(params[:id])
    if @project.update(payment_status: params[:payment_status])
      if params[:payment_status] == "완납"
        Notification.create!(
          user: current_user,
          project: @project,
          title: "입금 확인 완료",
          message: "#{@project.project_name} 현장의 잔금이 성공적으로 입금되었습니다! 수고하셨습니다 👏",
          status: "unread",
          category: "finance",
          link_url: "/projects/#{@project.id}"
        )
      end
      redirect_to @project, notice: "결제상태가 변경되었습니다."
    else
      redirect_to @project, alert: "결제상태 변경에 실패했습니다."
    end
  end

  def add_photos
    @project = current_user.projects.find(params[:id])
    begin
      if params[:photos].present?
        Array(params[:photos]).each do |photo|
          next if photo.blank?
          @project.photos.attach(photo)
        end
        render json: { success: true }
      else
        render json: { success: false, error: "사진을 찾을 수 없습니다." }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Photo Upload Error: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { success: false, error: e.message }, status: :internal_server_error
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

  # 특정 월의 캘린더 데이터 빌드 (메인 캘린더용)
  def build_month_data(base_date, user_id, selected_status)
    year = base_date.year
    month = base_date.month
    month_first = Date.new(year, month, 1)
    month_last = Date.new(year, month, -1)
    cal_start = month_first.beginning_of_week(:sunday)
    cal_end = month_last.end_of_week(:sunday)
    days = (cal_start..cal_end).to_a
    rows = days.each_slice(7).to_a

    schedules = ProjectSchedule
      .joins(:project)
      .where(projects: { user_id: user_id })
      .where(work_date: cal_start..cal_end)
      .includes(:project)

    if selected_status.present? && selected_status != "all"
      schedules = schedules.where(projects: { status: selected_status })
    end

    pbd = {}
    schedules.each do |s|
      pbd[s.work_date] ||= []
      pbd[s.work_date] << s.project unless pbd[s.work_date].include?(s.project)
    end

    { year: year, month: month, rows: rows, projects_by_date: pbd }
  end

  # 특정 월의 캘린더 데이터 빌드 (프로젝트 캘린더용)
  def build_month_data_for_project(base_date, project_ids)
    year = base_date.year
    month = base_date.month
    month_first = Date.new(year, month, 1)
    month_last = Date.new(year, month, -1)
    cal_start = month_first.beginning_of_week(:sunday)
    cal_end = month_last.end_of_week(:sunday)
    days = (cal_start..cal_end).to_a
    rows = days.each_slice(7).to_a

    schedules = ProjectSchedule
      .where(project_id: project_ids)
      .where(work_date: cal_start..cal_end)
      .includes(:project)

    pbd = {}
    schedules.each do |s|
      pbd[s.work_date] ||= []
      pbd[s.work_date] << s.project unless pbd[s.work_date].include?(s.project)
    end

    { year: year, month: month, rows: rows, projects_by_date: pbd }
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
      :mid_payment,
      :payment_status,
      :worker_names,
      :work_description,
      :tax_invoice_issued,
      selected_process_names: [],
      photos: []
    )
  end

  def require_premium_for_money!
    unless current_user.premium? || User::TESTING_PERIOD
      redirect_to subscription_path, alert: "돈 관리는 프리미엄 요금제 전용 기능입니다. 💰"
    end
  end
end
