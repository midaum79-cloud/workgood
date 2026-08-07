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

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:id])
  end

  def consultation_params
    params.require(:consultation).permit(:customer_name, :contact_number, :address, :consultation_date, :consultation_time, :memo)
  end
end
