class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.subscription_plan = "premium"
    @user.subscription_expires_at = Time.zone.parse("2026-05-30 23:59:59")

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "환영합니다, #{@user.name}님! 🎉 오픈 이벤트로 5월 30일까지 프리미엄 요금제가 무료 제공됩니다!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # 앱스토어 심사용: 계정 삭제 액션
    current_user.destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "계정이 정상적으로 삭제되었습니다."
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :phone)
  end
end
