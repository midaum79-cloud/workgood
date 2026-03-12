class WorkProcessesController < ApplicationController
  before_action :set_work_process, only: %i[show edit update destroy]

  def show
  end

  def new
    @work_process = WorkProcess.new
    @projects = Project.order(created_at: :desc)
  end

  def create
    @work_process = WorkProcess.new(work_process_params)
    assign_default_position(@work_process)

    if @work_process.save
      @work_process.sync_work_days!(params[:work_process][:selected_dates]) if params[:work_process][:selected_dates].present?
      redirect_to project_path(@work_process.project), notice: "공정이 등록되었습니다."
    else
      @projects = Project.order(created_at: :desc)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @work_process.update(work_process_params)
      @work_process.sync_work_days!(params[:work_process][:selected_dates]) if params[:work_process][:selected_dates].present?
      redirect_to work_process_path(@work_process, year: params[:year], month: params[:month]), notice: "공정이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    project = @work_process.project
    @work_process.destroy
    redirect_to project_path(project), notice: "공정이 삭제되었습니다."
  end

  private

  def set_work_process
    @work_process = WorkProcess.find(params[:id])
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
      :memo,
      selected_dates: []
    )
  end

  def assign_default_position(work_process)
    return if work_process.position.present?
    return unless work_process.project.present?

    max_position = work_process.project.work_processes.maximum(:position) || 0
    work_process.position = max_position + 1
  end
end