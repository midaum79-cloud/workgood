class PromoCodesController < ApplicationController
  before_action :require_login

  def apply
    code_string = params[:code].to_s.strip.upcase
    promo_code = PromoCode.find_by(code: code_string)

    if promo_code.nil?
      redirect_back fallback_location: subscription_path, alert: "유효하지 않은 프로모션 쿠폰입니다."
      return
    end

    unless promo_code.active?
      redirect_back fallback_location: subscription_path, alert: "이미 만료된 쿠폰입니다."
      return
    end

    if promo_code.max_uses.present? && promo_code.current_uses >= promo_code.max_uses
      redirect_back fallback_location: subscription_path, alert: "선착순 사용 인원이 초과된 쿠폰입니다."
      return
    end

    if current_user.promo_code_usages.exists?(promo_code: promo_code)
      redirect_back fallback_location: subscription_path, alert: "이미 사용하신 쿠폰입니다."
      return
    end

    ActiveRecord::Base.transaction do
      PromoCodeUsage.create!(user: current_user, promo_code: promo_code)
      promo_code.increment!(:current_uses)

      current_user.subscription_plan = "premium"
      if current_user.subscription_expires_at.nil? || current_user.subscription_expires_at < Time.current
        current_user.subscription_expires_at = Time.current + promo_code.reward_days.days
      else
        current_user.subscription_expires_at += promo_code.reward_days.days
      end
      current_user.save!
    end

    redirect_back fallback_location: subscription_path, notice: "🎉 쿠폰이 성공적으로 적용되었습니다! (프리미엄 #{promo_code.reward_days}일 추가)"
  rescue => e
    redirect_back fallback_location: subscription_path, alert: "쿠폰 등록 중 오류가 발생했습니다."
  end
end
