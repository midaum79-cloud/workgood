class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    auth = request.env["omniauth.auth"]

    user = User.find_or_create_from_omniauth(auth)

    if user
      session[:user_id] = user.id
      redirect_to root_path, notice: "구글 계정으로 로그인되었습니다. 환영합니다, #{user.name}님!"
    else
      redirect_to login_path, alert: "로그인에 실패했습니다. 다시 시도해주세요."
    end
  end

  def failure
    redirect_to login_path, alert: "로그인이 취소되었습니다."
  end
end
