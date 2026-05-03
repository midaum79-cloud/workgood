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

    # 이미지를 서버에서 압축 후 DB에 직접 저장 (R2/S3 완전 우회)
    if params.dig(:receipt, :image).present?
      uploaded = params[:receipt][:image]
      compressed = compress_image(uploaded)
      @receipt.image_data = compressed[:data]
      @receipt.image_content_type = compressed[:content_type]
    end

    if @receipt.image_data.present? && @receipt.save
      redirect_to receipts_path(year: @receipt.receipt_date.year, month: @receipt.receipt_date.month), notice: "영수증이 저장되었습니다."
    else
      @selected_date = params.dig(:receipt, :receipt_date) || Date.current.to_s
      flash.now[:alert] = "이미지를 선택해주세요." if @receipt.image_data.blank?
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("Receipt create error: #{e.class} - #{e.message}")
    redirect_to receipts_path, alert: "저장 중 오류가 발생했습니다. 다시 시도해 주세요."
  end

  # DB에 저장된 이미지를 직접 서빙
  def serve_image
    receipt = current_user.receipts.find(params[:id])
    if receipt.image_data.present?
      expires_in 1.hour, public: false
      send_data receipt.image_data,
                type: receipt.image_content_type || "image/jpeg",
                disposition: "inline"
    else
      head :not_found
    end
  end

  def destroy
    @receipt = current_user.receipts.find(params[:id])
    month = @receipt.receipt_date.month
    year = @receipt.receipt_date.year
    @receipt.destroy
    redirect_to receipts_path(year: year, month: month), notice: "영수증이 삭제되었습니다."
  end

  private

  # 이미지를 800px로 리사이즈하고 JPEG 70% 품질로 압축
  # 원본 ~3-5MB → 압축 후 ~30-80KB
  def compress_image(uploaded_file)
    require "image_processing/vips"

    processed = ImageProcessing::Vips
      .source(uploaded_file.tempfile)
      .resize_to_limit(800, 800)
      .convert("jpeg")
      .saver(quality: 70, strip: true)
      .call

    {
      data: processed.read,
      content_type: "image/jpeg"
    }
  rescue => e
    # 압축 실패 시 원본 그대로 저장
    Rails.logger.warn("이미지 압축 실패 (#{e.message}), 원본 저장")
    uploaded_file.rewind
    {
      data: uploaded_file.read,
      content_type: uploaded_file.content_type
    }
  end

  def require_standard_for_receipts!
    unless current_user.standard_or_above?
      redirect_to subscription_path, alert: "월별 영수증 관리는 스탠다드 이상 요금제 전용 기능입니다. 📊"
    end
  end
end
