class PromoCodesController < ApplicationController
  before_action :require_login

  def apply
    code_string = params[:code].to_s.strip.upcase
    promo_code = PromoCode.find_by(code: code_string)

    if promo_code.nil?
      redirect_to subscription_path, alert: "유효하지 않은 프로모션 코드입니다."
      return
    end

    unless promo_code.active?
      redirect_to subscription_path, alert: "이미 만료된 프로모션 코드입니다."
      return
    end

    if promo_code.max_uses.present? && promo_code.current_uses >= promo_code.max_uses
      redirect_to subscription_path, alert: "이미 한도가 초과된 프로모션 코드입니다."
      return
    end

    if current_user.promo_code_usages.exists?(promo_code: promo_code)
      redirect_to subscription_path, alert: "이미 사용하신 프로모션 코드입니다."
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

    redirect_to subscription_path, notice: "🎉 프로모션 코드가 성공적으로 적용되었습니다! (#{promo_code.reward_days}일 추가)"
  rescue => e
    redirect_to subscription_path, alert: "프로모션 코드 적용 중 오류가 발생했습니다."
  end
end
