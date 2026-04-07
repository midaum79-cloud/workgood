class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2, :apple]

  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_omniauth(auth)

    if user.persisted?
      # 앱에서 온 요청인지 확인 (OmniAuth state 또는 origin 파라미터)
      origin = request.env["omniauth.origin"] || ""
      from_app = origin.include?("source=app")

      if from_app
        # 일회용 로그인 토큰 생성 → 앱으로 딥링크 복귀
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)
        @deep_link = "workgood://auth/callback?token=#{token}"

        # nonce가 있으면 저장 (iOS 폴링용)
        nonce = origin.match(/nonce=([^&]+)/)&.captures&.first
        if nonce
          Rails.cache.write("app_login_nonce:#{nonce}", token, expires_in: 120.seconds)
        end

        render "omniauth_callbacks/app_redirect", layout: false
      else
        session[:user_id] = user.id
        redirect_to root_path, notice: "Google 로그인 성공!"
      end
    else
      redirect_to login_path, alert: "로그인 실패. 다시 시도해주세요."
    end
  end

  def apple
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_omniauth(auth)

    if user.persisted?
      origin = request.env["omniauth.origin"] || ""
      from_app = origin.include?("source=app")

      if from_app
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)
        @deep_link = "ilmeori://auth/callback?token=#{token}"

        nonce = origin.match(/nonce=([^&]+)/)&.captures&.first
        if nonce
          Rails.cache.write("app_login_nonce:#{nonce}", token, expires_in: 120.seconds)
        end

        render "omniauth_callbacks/app_redirect", layout: false
      else
        session[:user_id] = user.id
        redirect_to root_path, notice: "Apple 로그인 성공!"
      end
    else
      redirect_to login_path, alert: "로그인 실패. 다시 시도해주세요."
    end
  end

  # 앱에서 딥링크로 받은 토큰을 검증하고 세션 생성
  def token_login
    token = params[:token]
    user_id = Rails.cache.read("app_login_token:#{token}")

    if user_id
      Rails.cache.delete("app_login_token:#{token}")
      session[:user_id] = user_id
      redirect_to root_path
    else
      redirect_to login_path, alert: "로그인 토큰이 만료되었습니다. 다시 시도해주세요."
    end
  end

  # iOS 폴링: nonce로 토큰 조회
  def check_login
    nonce = params[:nonce]
    token = Rails.cache.read("app_login_nonce:#{nonce}")
    if token
      render json: { token: token }
    else
      render json: { token: nil }
    end
  end

  def failure
    redirect_to login_path, alert: "인증 실패: #{params[:message]}"
  end
end

