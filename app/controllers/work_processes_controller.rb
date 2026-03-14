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
    respond_to do |format|
      if @work_process.update(work_process_params)
        selected_dates = params.dig(:work_process, :selected_dates)
        if selected_dates.present?
          @work_process.sync_work_days!(Array(selected_dates).reject(&:blank?))
        elsif @work_process.start_date.present? && @work_process.work_days.empty?
          # Auto-fill work_days from start_date..end_date range for calendar display
          date_range = (@work_process.start_date.to_date..(@work_process.end_date || @work_process.start_date).to_date).to_a
          date_range.each { |d| @work_process.work_days.find_or_create_by!(work_date: d) }
        end

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "work_process_costs_#{@work_process.id}",
            partial: "work_processes/costs",
            locals: { work_process: @work_process }
          )
        end
        format.html { redirect_to work_process_path(@work_process, year: params[:year], month: params[:month]), notice: "공정이 수정되었습니다." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
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
      :budget,
      :memo,
      :description,
      :vendor_input_method,
      :new_vendor_name,
      :new_vendor_contact_name,
      :new_vendor_phone
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