class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :google_oauth2, :apple ]

  def google_oauth2
    auth = request.env["omniauth.auth"]
    unless auth
      Rails.logger.error "[OmniAuth] Google auth data is nil"
      return redirect_to login_path, alert: "인증 정보를 받지 못했습니다. 다시 시도해주세요."
    end

    user = User.find_or_create_from_omniauth(auth)

    if user&.persisted?
      origin = request.env["omniauth.origin"] || ""
      auth_params = request.env["omniauth.params"] || {}
      from_app = origin.include?("source=app") || auth_params["source"] == "app"

      if from_app
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)
        @deep_link = "workgood://auth/callback?token=#{token}"

        nonce = origin.match(/nonce=([^&]+)/)&.captures&.first || auth_params["nonce"]
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
  rescue => e
    Rails.logger.error "[OmniAuth] Google callback error: #{e.class} - #{e.message}"
    Rails.logger.error "[OmniAuth] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    redirect_to login_path, alert: "Google 로그인 중 오류가 발생했습니다. 다시 시도해주세요."
  end

  def apple
    auth = request.env["omniauth.auth"]
    unless auth
      Rails.logger.error "[OmniAuth] Apple auth data is nil"
      return redirect_to login_path, alert: "Apple 인증 정보를 받지 못했습니다. 다시 시도해주세요."
    end

    user = User.find_or_create_from_omniauth(auth)

    if user&.persisted?
      origin = request.env["omniauth.origin"] || ""
      auth_params = request.env["omniauth.params"] || {}
      from_app = origin.include?("source=app") || auth_params["source"] == "app"

      if from_app
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)
        @deep_link = "workgood://auth/callback?token=#{token}"

        nonce = origin.match(/nonce=([^&]+)/)&.captures&.first || auth_params["nonce"]
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
  rescue => e
    Rails.logger.error "[OmniAuth] Apple callback error: #{e.class} - #{e.message}"
    Rails.logger.error "[OmniAuth] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    redirect_to login_path, alert: "Apple 로그인 중 오류가 발생했습니다. 다시 시도해주세요."
  end

  # 앱에서 딥링크로 받은 토큰을 검증하고 세션 생성
  def token_login
    token = params[:token]
    user_id = Rails.cache.read("app_login_token:#{token}")

    if user_id
      # 딥링크와 폴링이 동시에 요청될 때 발생하는 Race Condition 차단
      # 즉시 삭제하지 않고 60초 캐시 만료로 자연 소멸되도록 유지
      # Rails.cache.delete("app_login_token:#{token}")
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
    error = request.env["omniauth.error"]
    Rails.logger.error "[OmniAuth] Auth failure: message=#{params[:message]}, strategy=#{params[:strategy]}, origin=#{params[:origin]}"
    if error
      Rails.logger.error "[OmniAuth] Error class: #{error.class}, message: #{error.message}"
      Rails.logger.error "[OmniAuth] Backtrace:\n#{error.backtrace&.first(15)&.join("\n")}"
    end
    redirect_to login_path, alert: "인증 실패: #{params[:message]}"
  end
end
