class VendorsController < ApplicationController
  before_action :set_vendor, only: %i[show edit update destroy]

  def index
    @vendor_type = params[:vendor_type] || "company"
    @vendors =
      if @vendor_type == "individual"
        Vendor.ordered.where(vendor_type: "individual")
      else
        Vendor.ordered.where(vendor_type: ["company", nil, ""])
      end
    @unread_notifications_count = Notification.where(status: "unread").count
  end

  def search
    query = params[:q].to_s.strip
    vendor_type = params[:vendor_type]
    vendors = Vendor.ordered

    # vendor_type이 null인 기존 데이터도 '업체' 탭에서 표시
    if vendor_type == "company"
      vendors = vendors.where(vendor_type: [nil, "", "company"])
    elsif vendor_type.present?
      vendors = vendors.where(vendor_type: vendor_type)
    end

    if query.present?
      vendors = vendors.select { |v| chosung_match?(v.name, query) }
    end

    render json: vendors.map { |v|
      {
        id: v.id,
        name: v.name,
        contact_name: v.contact_name,
        phone: v.phone,
        vendor_type: v.vendor_type
      }
    }
  end

  def show
  end

  def new
    @vendor = Vendor.new
  end

  def edit
  end

  def create
    @vendor = Vendor.new(vendor_params)
    if @vendor.save
      redirect_path = @vendor.vendor_type.present? ? process_templates_path : vendors_path
      redirect_to redirect_path, notice: "거래처가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vendor.update(vendor_params)
      redirect_path = @vendor.vendor_type.present? ? process_templates_path : vendors_path
      redirect_to redirect_path, notice: "거래처 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    vendor_type = @vendor.vendor_type
    @vendor.destroy
    redirect_path = vendor_type.present? ? process_templates_path : vendors_path
    redirect_to redirect_path, notice: "거래처가 삭제되었습니다."
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :contact_name, :phone, :specialty, :memo, :business_number, :address, :vendor_type)
  end

  CHO = %w[ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ].freeze
  HANGUL_START = 0xAC00
  CHO_PERIOD = 21 * 28

  def get_chosung(str)
    str.chars.map do |ch|
      code = ch.ord
      if code >= HANGUL_START && code <= 0xD7A3
        CHO[(code - HANGUL_START) / CHO_PERIOD]
      else
        ch
      end
    end.join
  end

  def all_chosung?(str)
    str.chars.all? { |ch| CHO.include?(ch) }
  end

  def chosung_match?(name, query)
    return true if name.downcase.include?(query.downcase)
    if all_chosung?(query)
      get_chosung(name).include?(query)
    else
      false
    end
  end
end
