class NativeGoogleAuthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    id_token_str = params[:idToken]
    if id_token_str.blank?
      return render json: { error: "Missing ID token" }, status: :bad_request
    end

    begin
      # JWT 디코딩 (서명 검증 전 payload 확인)
      id_token = JSON::JWT.decode(id_token_str, :skip_verification)

      # Google 공개키로 서명 검증
      jwk_set = JSON.parse(URI.open("https://www.googleapis.com/oauth2/v3/certs").read)
      jwk = jwk_set["keys"].find { |k| k["kid"] == id_token.kid }
      if jwk
        public_key = JSON::JWK.new(jwk).to_key
        JSON::JWT.decode(id_token_str, public_key)
      else
        raise "Google public key not found for kid: #{id_token.kid}"
      end

      # Claims 검증
      raise "Invalid issuer" unless %w[accounts.google.com https://accounts.google.com].include?(id_token[:iss])
      # audience 검증: Web, iOS, Android 클라이언트 ID 모두 허용
      valid_audiences = [
        ENV["GOOGLE_CLIENT_ID"],                                                          # Web
        "944339730636-2enclt34i6lq8g203bk0afhorbll1dt3.apps.googleusercontent.com",       # iOS
        "944339730636-5q5tarbc3dsf0s6rfcnfh70q5oi8kpvf.apps.googleusercontent.com"        # Android
      ].compact
      raise "Invalid audience" unless valid_audiences.include?(id_token[:aud])
      raise "Token expired" unless id_token[:exp] >= Time.now.to_i

      # 사용자 정보 추출
      google_uid   = id_token[:sub]
      google_email = id_token[:email]&.downcase
      google_name  = id_token[:name]
      first_name   = id_token[:given_name]
      last_name    = id_token[:family_name]

      # OmniAuth 호환 auth 해시 생성
      auth = OpenStruct.new(
        provider: "google_oauth2",
        uid: google_uid,
        info: OpenStruct.new(
          email: google_email,
          name: google_name,
          first_name: first_name,
          last_name: last_name
        )
      )

      user = User.find_or_create_from_omniauth(auth)

      if user&.persisted?
        # 일회용 로그인 토큰 생성 (token_login 용)
        token = SecureRandom.hex(32)
        Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)

        render json: { success: true, token: token }
      else
        error_msg = user ? user.errors.full_messages.join(", ") : "DB creation failed"
        render json: { error: "User creation failed: #{error_msg}" }, status: :unprocessable_entity
      end

    rescue => e
      Rails.logger.error "[Native Google Login] Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace&.first(5)&.join("\n")
      render json: { error: e.message }, status: :unauthorized
    end
  end
end
