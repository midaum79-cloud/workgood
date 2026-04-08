class SessionsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
  end

  def create
    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s

    # 빈 값 체크
    if email.blank? || password.blank?
      flash.now[:alert] = "이메일과 비밀번호를 입력해주세요."
      return render :new, status: :unprocessable_entity
    end

    user = User.find_by(email: email)

    if user&.authenticate(password)
      session[:user_id] = user.id
      redirect_to session.delete(:return_to) || root_path, notice: "환영합니다, #{user.name}님!"
    else
      flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "로그아웃 되었습니다."
  end
end
