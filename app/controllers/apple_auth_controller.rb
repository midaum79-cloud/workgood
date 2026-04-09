require "json/jwt"
require "net/http"
require "uri"

class AppleAuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :callback ]

  # GET /auth/apple → Apple 로그인 페이지로 리다이렉트
  def redirect
    base_state = SecureRandom.hex(16)
    if params[:origin].present?
      state = "#{base_state}|#{Base64.urlsafe_encode64(params[:origin])}"
    else
      state = base_state
    end
    nonce = SecureRandom.hex(16)
    session[:apple_state] = state
    session[:apple_nonce] = nonce

    params_hash = {
      client_id:     apple_client_id,
      redirect_uri:  apple_redirect_uri,
      response_type: "code id_token",
      response_mode: "form_post",
      scope:         "name email",
      state:         state,
      nonce:         nonce
    }

    query = params_hash.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
    redirect_to "https://appleid.apple.com/auth/authorize?#{query}", allow_other_host: true
  end

  # POST /auth/apple/callback → Apple이 코드를 보내는 곳
  def callback
    Rails.logger.info "[AppleAuth] Callback received. params keys: #{params.keys}"

    # State 검증 (선택적 - Apple 웹은 state를 잘 안 보낼 수 있음)
    code     = params[:code]
    id_token_str = params[:id_token]

    unless code || id_token_str
      Rails.logger.error "[AppleAuth] No code or id_token in callback"
      return redirect_to login_path, alert: "Apple 인증 정보를 받지 못했습니다. 다시 시도해주세요."
    end

    # id_token에서 사용자 정보 추출
    user_info = extract_user_from_id_token(id_token_str)
    unless user_info
      Rails.logger.error "[AppleAuth] Failed to extract user info from id_token"
      return redirect_to login_path, alert: "Apple 사용자 정보를 가져오지 못했습니다."
    end

    Rails.logger.info "[AppleAuth] User info extracted: uid=#{user_info[:uid]}, email=#{user_info[:email]}"

    # name은 첫 로그인 때만 Apple이 보냄
    apple_name = nil
    if params[:user].present?
      begin
        user_data = JSON.parse(params[:user])
        first = user_data.dig("name", "firstName").to_s
        last  = user_data.dig("name", "lastName").to_s
        apple_name = [ first, last ].reject(&:empty?).join(" ")
      rescue => e
        Rails.logger.warn "[AppleAuth] Failed to parse user name: #{e.message}"
      end
    end

    # User 생성/찾기
    uid   = user_info[:uid]
    email = user_info[:email]
    email ||= "apple_#{uid}@oauth.workgood.co.kr"

    user = User.find_by(provider: "apple", uid: uid)
    user ||= User.find_by(email: email) if email.present?
    user ||= User.new

    unless user.persisted?
      user.provider = "apple"
      user.uid      = uid
      user.email    = email
      user.name     = apple_name.presence || email.split("@").first
      user.subscription_plan    = "standard"
      user.subscription_expires_at = 1.month.from_now
      generated_password = SecureRandom.hex(24)
      user.password = generated_password
      user.password_confirmation = generated_password
    else
      user.provider = "apple"
      user.uid      = uid
      user.name     = apple_name if apple_name.present? && !user.persisted?
    end

    if user.save
      Rails.logger.info "[AppleAuth] User saved: id=#{user.id}"
      
      state_str = params[:state].to_s
      origin = ""
      if state_str.include?("|")
        encoded_origin = state_str.split("|").last
        begin
          origin = Base64.urlsafe_decode64(encoded_origin)
        rescue
        end
      end
      
      from_app = origin.include?("source=app")

      if from_app
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)
        @deep_link = "workgood://auth/callback?token=#{token}"

        app_nonce = origin.match(/nonce=([^&]+)/)&.captures&.first
        if app_nonce
          Rails.cache.write("app_login_nonce:#{app_nonce}", token, expires_in: 120.seconds)
        end

        render "omniauth_callbacks/app_redirect", layout: false
      else
        session[:user_id] = user.id
        redirect_to root_path, notice: "Apple 로그인 성공!"
      end
    else
      Rails.logger.error "[AppleAuth] User save failed: #{user.errors.full_messages}"
      redirect_to login_path, alert: "가입 처리 중 오류가 발생했습니다: #{user.errors.full_messages.join(', ')}"
    end

  rescue => e
    Rails.logger.error "[AppleAuth] Callback error: #{e.class} - #{e.message}"
    Rails.logger.error "[AppleAuth] Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
    redirect_to login_path, alert: "Apple 로그인 중 오류가 발생했습니다. 다시 시도해주세요."
  end

  private

  def extract_user_from_id_token(id_token_str)
    return nil if id_token_str.blank?

    parts = id_token_str.split('.')
    return nil unless parts.length >= 2

    # JWT payload is the second part, base64url encoded
    payload_base64 = parts[1]
    # Add padding if necessary
    payload_base64 += '=' * (4 - payload_base64.length % 4) if payload_base64.length % 4 != 0
    
    decoded = JSON.parse(Base64.urlsafe_decode64(payload_base64)).with_indifferent_access
    Rails.logger.info "[AppleAuth] id_token decoded via Base64: sub=#{decoded[:sub]}, email=#{decoded[:email]}"

    {
      uid:   decoded[:sub],
      email: decoded[:email]
    }
  rescue => e
    Rails.logger.error "[AppleAuth] id_token decode error: #{e.class} - #{e.message}"
    nil
  end

  def apple_client_id
    ENV["APPLE_CLIENT_ID"]
  end

  def apple_redirect_uri
    "https://www.workgood.co.kr/apple_auth/callback"
  end
end
