class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_omniauth(auth)

    if user.persisted?
      session[:user_id] = user.id
      redirect_to root_path, notice: "Google 로그인 성공!"
    else
      redirect_to login_path, alert: "로그인 실패. 다시 시도해주세요."
    end
  end

  def failure
    redirect_to login_path, alert: "인증 실패: #{params[:message]}"
  end
end
