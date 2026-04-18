class ReceiptsController < ApplicationController
  before_action :require_login
  before_action :require_standard_for_receipts!

  def index
    @current_date = begin
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    rescue
      Date.current.beginning_of_month
    end

    @receipts = current_user.receipts
                            .with_attached_image
                            .where(receipt_date: @current_date.beginning_of_month..@current_date.end_of_month)
                            .order(receipt_date: :asc, created_at: :asc)
    
    # 이미지 없는 레코드 필터링
    @receipts = @receipts.select { |r| r.image.attached? }
    
    # 캘린더용으로 날짜별 그룹핑
    @receipts_by_date = @receipts.group_by(&:receipt_date)
  rescue => e
    # 디버깅용: 에러 메시지를 flash로 표시
    @current_date = Date.current.beginning_of_month
    @receipts_by_date = {}
    flash.now[:alert] = "영수증 목록 에러: #{e.class} - #{e.message}"
    render :index
  end

  def new
    @receipt = current_user.receipts.build
    @selected_date = params[:date].presence || Date.current.to_s
  end

  def create
    @receipt = current_user.receipts.build(receipt_params)
    if @receipt.save
      redirect_to receipts_path(year: @receipt.receipt_date.year, month: @receipt.receipt_date.month), notice: '영수증이 저장되었습니다.'
    else
      @selected_date = @receipt.receipt_date || Date.current.to_s
      flash.now[:alert] = "저장 실패: #{@receipt.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  rescue => e
    redirect_to receipts_path, alert: "저장 에러: #{e.class} - #{e.message}"
  end

  def destroy
    @receipt = current_user.receipts.find(params[:id])
    month = @receipt.receipt_date.month
    year = @receipt.receipt_date.year
    @receipt.destroy
    redirect_to receipts_path(year: year, month: month), notice: '영수증이 삭제되었습니다.'
  end

  private

  def receipt_params
    params.require(:receipt).permit(:receipt_date, :amount, :memo, :image)
  end

  def require_standard_for_receipts!
    unless current_user.standard_or_above?
      redirect_to subscription_path, alert: '월별 영수증 관리는 스탠다드 이상 요금제 전용 기능입니다. 📊'
    end
  end
end
