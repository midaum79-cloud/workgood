class MyAccountController < ApplicationController
  before_action :require_login

  def show
    @project_count   = current_user.projects.count
    @plan_limit      = current_user.plan_limit
  end
  def documents
  end

  def update_documents
    user_params = params.fetch(:user, {}).permit(:business_card, :business_registration, :bankbook_copy, :business_bankbook_copy, :bank_name, :bank_account_number, :bank_account_holder, :team_name, :role, :name, :phone, :address)

    current_user.update(business_card_b64: Base64.strict_encode64(user_params[:business_card].read)) if user_params[:business_card].present?
    current_user.update(business_registration_b64: Base64.strict_encode64(user_params[:business_registration].read)) if user_params[:business_registration].present?
    current_user.update(bankbook_copy_b64: Base64.strict_encode64(user_params[:bankbook_copy].read)) if user_params[:bankbook_copy].present?
    current_user.update(business_bankbook_copy_b64: Base64.strict_encode64(user_params[:business_bankbook_copy].read)) if user_params[:business_bankbook_copy].present?

    text_attrs = user_params.except(:business_card, :business_registration, :bankbook_copy, :business_bankbook_copy).to_h
    current_user.update(text_attrs) if text_attrs.present?

    current_user.regenerate_document_share_token if current_user.document_share_token.blank?

    respond_to do |format|
      format.html { redirect_to my_account_documents_path, notice: "비즈니스 문서를 성공적으로 업데이트했습니다." }
      format.json { head :ok }
    end
  end

  def delete_document
    type = params[:type]
    if %w[business_card business_registration bankbook_copy business_bankbook_copy].include?(type)
      current_user.update("#{type}_b64" => nil)
      redirect_to my_account_documents_path, notice: "해당 서류가 삭제되었습니다."
    else
      redirect_to my_account_documents_path, alert: "잘못된 요청입니다."
    end
  end

  def biz_card_generator
  end

  def increment_biz_card_gen
    if current_user.biz_card_generations_count.to_i < 10
      current_user.increment!(:biz_card_generations_count)
      render json: { success: true }
    else
      render json: { success: false, limit_reached: true }
    end
  end

  def bank_card_generator
  end

  def increment_bank_card_gen
    if current_user.bank_card_generations_count.to_i < 10
      current_user.increment!(:bank_card_generations_count)
      render json: { success: true }
    else
      render json: { success: false, limit_reached: true }
    end
  end
end
