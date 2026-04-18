class MyAccountController < ApplicationController
  before_action :require_login
  skip_before_action :verify_authenticity_token, only: [:cache_image_for_download]

  def show
    @project_count   = current_user.projects.count
    @plan_limit      = current_user.plan_limit
  end

  def documents
  end

  def update_documents
    user_params = params.fetch(:user, {}).permit(
      :business_card, :business_registration,
      :bankbook_copy, :business_bankbook_copy,
      :bank_name, :bank_account_number, :bank_account_holder,
      :team_name, :role, :name, :phone, :address
    )

    update_file_attribute(:business_card_b64, user_params[:business_card])
    update_file_attribute(:business_registration_b64, user_params[:business_registration])
    update_file_attribute(:bankbook_copy_b64, user_params[:bankbook_copy])
    update_file_attribute(:business_bankbook_copy_b64, user_params[:business_bankbook_copy])

    if params[:business_card_base64_direct].present?
      current_user.update(business_card_b64: params[:business_card_base64_direct].split(',').last)
    end
    
    if params[:bankbook_copy_base64_direct].present?
      current_user.update(bankbook_copy_b64: params[:bankbook_copy_base64_direct].split(',').last)
    end

    text_attrs = user_params.except(
      :business_card, :business_registration, :bankbook_copy, :business_bankbook_copy
    ).to_h
    current_user.update(text_attrs) if text_attrs.present?

    current_user.regenerate_document_share_token if current_user.document_share_token.blank?

    respond_to do |format|
      format.html { redirect_to my_account_documents_path, notice: '비즈니스 문서를 성공적으로 업데이트했습니다.' }
      format.json { head :ok }
    end
  end

  def delete_document
    type = params[:type]
    if %w[business_card business_registration bankbook_copy business_bankbook_copy].include?(type)
      current_user.update("#{type}_b64" => nil)
      redirect_to my_account_documents_path, notice: '해당 서류가 삭제되었습니다.'
    else
      redirect_to my_account_documents_path, alert: '잘못된 요청입니다.'
    end
  end

  def biz_card_generator
  end

  def increment_biz_card_gen
    if current_user.biz_card_generations_count.to_i < 30
      current_user.increment!(:biz_card_generations_count)
      render json: { success: true }
    else
      render json: { success: false, limit_reached: true }
    end
  end

  def bank_card_generator
  end

  def increment_bank_card_gen
    if current_user.bank_card_generations_count.to_i < 30
      current_user.increment!(:bank_card_generations_count)
      render json: { success: true }
    else
      render json: { success: false, limit_reached: true }
    end
  end

  def cache_image_for_download
    uuid = SecureRandom.uuid
    base64_data = params[:image_base64]
    if base64_data.present?
      Rails.cache.write("image_download_#{uuid}", base64_data, expires_in: 10.minutes)
      render json: { success: true, uuid: uuid, url: download_cached_image_url(uuid: uuid) }
    else
      render json: { success: false }
    end
  end

  def download_cached_image
    safe_uuid = params[:uuid].to_s.gsub(/[^a-zA-Z0-9-]/, '')
    base64_data = Rails.cache.read("image_download_#{safe_uuid}")
    
    if base64_data.present?
      image_data = Base64.decode64(base64_data.split(',').last)
      send_data image_data,
                type: 'image/png',
                disposition: 'inline',
                filename: "일잘러_이미지_#{safe_uuid[0..5]}.png"
    else
      render plain: "이미지 링크가 만료되었거나 찾을 수 없습니다. (10분 한정)\n앱으로 돌아가 다시 시도해주세요.", status: 404
    end
  end

  private

  def update_file_attribute(attribute, file_param)
    return unless file_param.present?

    current_user.update(attribute => Base64.strict_encode64(file_param.read))
  end
end
