class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.subscription_plan = "standard"
    @user.subscription_expires_at = 1.month.from_now

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "환영합니다, #{@user.name}님! 🎉 스탠다드 플랜 1개월 무료체험이 시작되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :phone)
  end
end
