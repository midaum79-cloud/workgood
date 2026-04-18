class ReceiptsController < ApplicationController
  before_action :require_login
  before_action :require_standard_for_receipts!

  def index
    @current_date = begin
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    rescue
      Date.current.beginning_of_month
    end

    # DB에 직접 저장된 이미지가 있는 영수증만 표시
    @receipts = current_user.receipts
                            .where.not(image_data: nil)
                            .where(receipt_date: @current_date.beginning_of_month..@current_date.end_of_month)
                            .order(receipt_date: :asc, created_at: :asc)
    
    # 캘린더용으로 날짜별 그룹핑
    @receipts_by_date = @receipts.group_by(&:receipt_date)
  end

  def new
    @receipt = current_user.receipts.build
    @selected_date = params[:date].presence || Date.current.to_s
  end

  def create
    @receipt = current_user.receipts.build(
      receipt_date: params.dig(:receipt, :receipt_date)
    )

    # 이미지를 DB에 직접 저장 (R2/S3 우회)
    if params.dig(:receipt, :image).present?
      uploaded = params[:receipt][:image]
      @receipt.image_data = uploaded.read
      @receipt.image_content_type = uploaded.content_type
    end

    if @receipt.image_data.present? && @receipt.save
      redirect_to receipts_path(year: @receipt.receipt_date.year, month: @receipt.receipt_date.month), notice: '영수증이 저장되었습니다.'
    else
      @selected_date = params.dig(:receipt, :receipt_date) || Date.current.to_s
      flash.now[:alert] = '이미지를 선택해주세요.' if @receipt.image_data.blank?
      render :new, status: :unprocessable_entity
    end
  rescue => e
    redirect_to receipts_path, alert: "저장 에러: #{e.message}"
  end

  # DB에 저장된 이미지를 직접 서빙
  def serve_image
    receipt = current_user.receipts.find(params[:id])
    if receipt.image_data.present?
      send_data receipt.image_data,
                type: receipt.image_content_type || 'image/jpeg',
                disposition: 'inline'
    else
      head :not_found
    end
  end

  def destroy
    @receipt = current_user.receipts.find(params[:id])
    month = @receipt.receipt_date.month
    year = @receipt.receipt_date.year
    @receipt.destroy
    redirect_to receipts_path(year: year, month: month), notice: '영수증이 삭제되었습니다.'
  end

  private

  def require_standard_for_receipts!
    unless current_user.standard_or_above?
      redirect_to subscription_path, alert: '월별 영수증 관리는 스탠다드 이상 요금제 전용 기능입니다. 📊'
    end
  end
end
