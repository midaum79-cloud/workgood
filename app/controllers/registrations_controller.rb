class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.subscription_plan = "free"

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "회원가입이 완료되었습니다. 환영합니다, #{@user.name}님!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :phone)
  end
end
