class WorkProcessesController < ApplicationController
  before_action :set_work_process, only: %i[show edit update destroy]
  before_action :create_or_find_vendor, only: %i[create update]

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
      selected_dates = params.dig(:work_process, :selected_dates)
      @work_process.sync_work_days!(Array(selected_dates).reject(&:blank?)) if selected_dates.present?
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
      # Sync dates separately — even if this fails, the main update already succeeded
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

    # Handle the "new vendor" mode
    if wp_params[:vendor_input_method] == "new"
      new_name = wp_params[:new_vendor_name]&.strip
      
      if new_name.present?
        # Create or update vendor if it doesn't exist
        vendor = Vendor.find_by(name: new_name)
        unless vendor
          vendor = Vendor.create!(
            name: new_name,
            contact_name: wp_params[:new_vendor_contact_name]&.strip,
            phone: wp_params[:new_vendor_phone]&.strip
          )
        end
        # Map the freshly created/found vendor to the normal vendor_name property
        wp_params[:vendor_name] = new_name
      end
    end
  end
end