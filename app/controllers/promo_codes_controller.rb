class PromoCodesController < ApplicationController
  before_action :require_login

  def apply
    code_string = params[:code].to_s.strip.upcase
    error_message = nil
    success_message = nil

    ActiveRecord::Base.transaction do
      promo_code = PromoCode.lock.find_by(code: code_string)

      if promo_code.nil?
        error_message = "유효하지 않은 프로모션 쿠폰입니다."
        raise ActiveRecord::Rollback
      end

      unless promo_code.active?
        error_message = "이미 만료된 쿠폰입니다."
        raise ActiveRecord::Rollback
      end

      if promo_code.max_uses.present? && promo_code.current_uses >= promo_code.max_uses
        error_message = "선착순 사용 인원이 초과된 쿠폰입니다."
        raise ActiveRecord::Rollback
      end

      if current_user.promo_code_usages.exists?(promo_code: promo_code)
        error_message = "이미 사용하신 쿠폰입니다."
        raise ActiveRecord::Rollback
      end

      PromoCodeUsage.create!(user: current_user, promo_code: promo_code)
      promo_code.increment!(:current_uses)

      current_user.subscription_plan = "premium"
      if current_user.subscription_expires_at.nil? || current_user.subscription_expires_at < Time.current
        current_user.subscription_expires_at = Time.current + promo_code.reward_days.days
      else
        current_user.subscription_expires_at += promo_code.reward_days.days
      end
      current_user.save!

      success_message = "🎉 쿠폰이 성공적으로 적용되었습니다! (프리미엄 #{promo_code.reward_days}일 추가)"
    end

    if error_message
      redirect_back fallback_location: subscription_path, alert: error_message
    else
      redirect_back fallback_location: subscription_path, notice: success_message
    end
  rescue => e
    Rails.logger.error("PromoCode Error: #{e.message}")
    redirect_back fallback_location: subscription_path, alert: "쿠폰 등록 중 오류가 발생했습니다."
  end
end
