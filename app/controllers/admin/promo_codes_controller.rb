class Admin::PromoCodesController < Admin::BaseController
  layout 'application'

  def index
    @promo_codes = PromoCode.order(created_at: :desc)
  end

  def create
    @promo_code = PromoCode.new(promo_code_params)
    @promo_code.code = @promo_code.code.to_s.strip.upcase

    if @promo_code.save
      redirect_to admin_promo_codes_path, notice: "프로모션 코드가 성공적으로 생성되었습니다."
    else
      redirect_to admin_promo_codes_path, alert: "프로모션 코드 생성에 실패했습니다: #{@promo_code.errors.full_messages.join(', ')}"
    end
  end

  private

  def promo_code_params
    params.require(:promo_code).permit(:code, :reward_days, :max_uses)
  end
end
