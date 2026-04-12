class WorkProcessesController < ApplicationController
  before_action :require_login
  before_action :set_work_process, only: %i[show edit update destroy]
  before_action :create_or_find_vendor, only: %i[create update]

  def show
  end

  def new
    @work_process = WorkProcess.new
    @projects = current_user.projects.order(created_at: :desc)
  end

  def create
    @work_process = WorkProcess.new(work_process_params)

    # 현재 사용자의 프로젝트만 허용
    unless current_user.projects.exists?(@work_process.project_id)
      return redirect_to projects_path, alert: "접근 권한이 없습니다."
    end

    assign_default_position(@work_process)

    if @work_process.save
      selected_dates = params.dig(:work_process, :selected_dates)
      @work_process.sync_work_days!(Array(selected_dates).reject(&:blank?)) if selected_dates.present?
      redirect_to project_path(@work_process.project), notice: "공정이 등록되었습니다."
    else
      @projects = current_user.projects.order(created_at: :desc)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @work_process.update(work_process_params)
      selected_dates = params.dig(:work_process, :selected_dates)
      if selected_dates.present?
        begin
          @work_process.sync_work_days!(Array(selected_dates).reject(&:blank?))
        rescue => sync_err
          Rails.logger.error "[WorkProcess#update sync_work_days!] #{sync_err.class}: #{sync_err.message}"
        end
      end
      redirect_to work_process_path(@work_process), notice: "공정이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "[WorkProcess#update] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to edit_work_process_path(@work_process), alert: "저장 오류: #{e.message}"
  end

  # POST /work_processes/quick_create (JSON)
  def quick_create
    project = current_user.projects.find(params[:project_id])
    max_pos = project.work_processes.maximum(:position) || 0

    wp = project.work_processes.create!(
      process_name: params[:process_name],
      position: max_pos + 1
    )

    if params[:work_date].present?
      wp.work_days.find_or_create_by!(work_date: params[:work_date])
    end

    render json: { success: true, work_process_id: wp.id }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def destroy
    project = @work_process.project
    @work_process.destroy
    redirect_to project_path(project), notice: "공정이 삭제되었습니다."
  end

  private

  def set_work_process
    # 현재 사용자의 프로젝트에 속한 공정만 접근 가능
    @work_process = WorkProcess.joins(:project)
                               .where(projects: { user_id: current_user.id })
                               .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "접근 권한이 없습니다."
  end

  def work_process_params
    params.require(:work_process).permit(
      :project_id,
      :process_name,
      :vendor_name,
      :contractor_name,
      :position,
      :status,
      :start_date,
      :end_date,
      :material_cost,
      :labor_cost,
      :budget,
      :memo,
      :description
    )
  end

  def assign_default_position(work_process)
    return if work_process.position.present?
    return unless work_process.project.present?

    max_position = work_process.project.work_processes.maximum(:position) || 0
    work_process.position = max_position + 1
  end

  def create_or_find_vendor
    wp_params = params[:work_process]
    return unless wp_params

    if wp_params[:vendor_input_method] == "new"
      new_name = wp_params[:new_vendor_name]&.strip

      if new_name.present?
        # 현재 사용자의 거래처에서만 검색, 없으면 생성
        vendor = current_user.vendors.find_by(name: new_name)
        unless vendor
          vendor = current_user.vendors.create!(
            name: new_name,
            contact_name: wp_params[:new_vendor_contact_name]&.strip,
            phone: wp_params[:new_vendor_phone]&.strip
          )
        end
        wp_params[:vendor_name] = new_name
      end
    end
  end
end
