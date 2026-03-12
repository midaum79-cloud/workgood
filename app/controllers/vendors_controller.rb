class VendorsController < ApplicationController
  before_action :set_vendor, only: %i[show edit update destroy]

  def index
    @vendors = Vendor.ordered
    @unread_notifications_count = Notification.where(status: "unread").count
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
      redirect_to vendors_path, notice: "업체가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to vendors_path, notice: "업체 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vendor.destroy
    redirect_to vendors_path, notice: "업체가 삭제되었습니다."
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :contact_name, :phone, :specialty, :memo)
  end
end
