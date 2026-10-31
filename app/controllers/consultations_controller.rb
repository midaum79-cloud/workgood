class ConsultationsController < ApplicationController
  before_action :require_login
  before_action :set_consultation, only: %i[update destroy]

  def create
    @consultation = current_user.consultations.build(consultation_params)

    if @consultation.save
      render json: { success: true, consultation: @consultation }
    else
      render json: { success: false, error: @consultation.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update
    if @consultation.update(consultation_params)
      render json: { success: true, consultation: @consultation }
    else
      render json: { success: false, error: @consultation.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def destroy
    @consultation.destroy
    render json: { success: true }
  end

  def move
    if params[:id].present?
      consultation = current_user.consultations.find(params[:id])
      consultation.update!(consultation_date: params[:new_date])
    elsif params[:old_date].present? && params[:schedule_type].present?
      scope = current_user.consultations.where(consultation_date: params[:old_date])
      if params[:schedule_type] == "as"
        scope = scope.where(schedule_type: "as")
      else
        scope = scope.where.not(schedule_type: "as").or(current_user.consultations.where(consultation_date: params[:old_date], schedule_type: nil))
      end
      scope.update_all(consultation_date: params[:new_date])
    end

    render json: { success: true }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:id])
  end

  def consultation_params
    params.require(:consultation).permit(:company_name, :customer_name, :contact_number, :address, :detail_address, :consultation_date, :consultation_time, :memo, :schedule_type)
  end
end
