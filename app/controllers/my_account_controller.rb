class MyAccountController < ApplicationController
  before_action :require_login

  def show
    @project_count   = current_user.projects.count
    @plan_limit      = current_user.plan_limit
  end
  def documents
  end

  def update_documents
    if current_user.premium?
      user_params = params.fetch(:user, {}).permit(:business_card, :business_registration, :bankbook_copy, :business_bankbook_copy)
      
      current_user.update(business_card_b64: Base64.strict_encode64(user_params[:business_card].read)) if user_params[:business_card].present?
      current_user.update(business_registration_b64: Base64.strict_encode64(user_params[:business_registration].read)) if user_params[:business_registration].present?
      current_user.update(bankbook_copy_b64: Base64.strict_encode64(user_params[:bankbook_copy].read)) if user_params[:bankbook_copy].present?
      current_user.update(business_bankbook_copy_b64: Base64.strict_encode64(user_params[:business_bankbook_copy].read)) if user_params[:business_bankbook_copy].present?
      
      current_user.regenerate_document_share_token if current_user.document_share_token.blank?
      
      redirect_to my_account_documents_path, notice: "비즈니스 문서를 성공적으로 업데이트했습니다."
    else
      redirect_to my_account_documents_path, alert: "비즈니스 서류 지갑 및 공유 기능은 프리미엄 요금제 전용입니다."
    end
  end

  def delete_document
    if current_user.premium?
      type = params[:type]
      if %w[business_card business_registration bankbook_copy business_bankbook_copy].include?(type)
        current_user.update("#{type}_b64" => nil)
        redirect_to my_account_documents_path, notice: "해당 서류가 삭제되었습니다."
      else
        redirect_to my_account_documents_path, alert: "잘못된 요청입니다."
      end
    else
      redirect_to my_account_documents_path, alert: "비즈니스 서류 지갑 및 공유 기능은 프리미엄 요금제 전용입니다."
    end
  end
end
