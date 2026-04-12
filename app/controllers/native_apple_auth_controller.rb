require "net/http"
require "uri"
require "json"
require "openssl"
require "base64"

class NativeAppleAuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]
  skip_before_action :require_login, only: [ :create ], raise: false

  # POST /auth/native_apple
  # 앱에서 네이티브 Apple Sign-In으로 받은 identityToken(JWT)을 검증하고 세션 토큰 발급
  def create
    id_token = params[:id_token]

    unless id_token.present?
      return render json: { error: "id_token is required" }, status: :bad_request
    end

    # JWT 검증
    user_info = verify_apple_identity_token(id_token)
    unless user_info
      return render json: { error: "Invalid or expired Apple identity token" }, status: :unauthorized
    end

    Rails.logger.info "[NativeApple] Verified user: uid=#{user_info[:uid]}, email=#{user_info[:email]}"

    # 유저 생성/조회 (기존 AppleAuthController와 동일한 로직)
    uid   = user_info[:uid]
    email = user_info[:email]
    email = "apple_#{uid}@oauth.workgood.co.kr" if email.blank?

    # 앱에서 전달한 이름 정보 (최초 로그인 시에만 Apple이 제공)
    apple_name = nil
    if params[:name].present?
      apple_name = params[:name].to_s.strip
    end

    user = User.find_by(provider: "apple", uid: uid)
    user ||= User.find_by(email: email) if email.present?
    user ||= User.new

    unless user.persisted?
      user.provider = "apple"
      user.uid      = uid
      user.email    = email
      user.name     = apple_name.presence || email.split("@").first
      user.subscription_plan    = "free"
      generated_password = SecureRandom.hex(24)
      user.password = generated_password
      user.password_confirmation = generated_password
    else
      user.provider = "apple"
      user.uid      = uid
      user.name     = apple_name if apple_name.present? && user.name.blank?
    end

    if user.save
      Rails.logger.info "[NativeApple] User saved: id=#{user.id}"

      # 1회용 세션 토큰 발급
      token = SecureRandom.hex(32)
      Rails.cache.write("app_login_token:#{token}", user.id, expires_in: 60.seconds)

      render json: { token: token, user_id: user.id }, status: :ok
    else
      Rails.logger.error "[NativeApple] User save failed: #{user.errors.full_messages}"
      render json: { error: "Failed to save user: #{user.errors.full_messages.join(', ')}" }, status: :unprocessable_entity
    end

  rescue => e
    Rails.logger.error "[NativeApple] Error: #{e.class} - #{e.message}"
    Rails.logger.error "[NativeApple] Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  private

  # Apple의 공개키로 identityToken(JWT) 서명을 검증하고 payload 반환
  def verify_apple_identity_token(id_token)
    # 1. JWT 헤더에서 kid 추출
    header_segment = id_token.split(".").first
    header_segment += "=" * (4 - header_segment.length % 4) if header_segment.length % 4 != 0
    header = JSON.parse(Base64.urlsafe_decode64(header_segment))
    kid = header["kid"]
    alg = header["alg"]

    Rails.logger.info "[NativeApple] JWT header: kid=#{kid}, alg=#{alg}"

    # 2. Apple 공개키 가져오기 (캐시 사용)
    apple_keys = fetch_apple_public_keys
    key_data = apple_keys.find { |k| k["kid"] == kid }
    unless key_data
      Rails.logger.error "[NativeApple] No matching Apple key found for kid=#{kid}"
      return nil
    end

    # 3. RSA 공개키 생성
    rsa_key = build_rsa_key(key_data)

    # 4. JWT payload 디코딩 및 검증
    payload_segment = id_token.split(".")[1]
    payload_segment += "=" * (4 - payload_segment.length % 4) if payload_segment.length % 4 != 0
    payload = JSON.parse(Base64.urlsafe_decode64(payload_segment)).with_indifferent_access

    # 5. 서명 검증
    header_and_payload = id_token.split(".")[0..1].join(".")
    signature_segment = id_token.split(".")[2]
    signature_segment += "=" * (4 - signature_segment.length % 4) if signature_segment.length % 4 != 0
    signature = Base64.urlsafe_decode64(signature_segment)

    unless rsa_key.verify("SHA256", signature, header_and_payload)
      Rails.logger.error "[NativeApple] JWT signature verification failed"
      return nil
    end

    # 6. 클레임 검증
    unless payload[:iss] == "https://appleid.apple.com"
      Rails.logger.error "[NativeApple] Invalid issuer: #{payload[:iss]}"
      return nil
    end

    apple_client_id = ENV["APPLE_CLIENT_ID"]
    app_bundle_id = "com.workgood.app"
    unless [ apple_client_id, app_bundle_id ].include?(payload[:aud])
      Rails.logger.error "[NativeApple] Invalid audience: #{payload[:aud]}"
      return nil
    end

    if payload[:exp].to_i < Time.now.to_i
      Rails.logger.error "[NativeApple] Token expired: exp=#{payload[:exp]}"
      return nil
    end

    {
      uid:   payload[:sub],
      email: payload[:email]
    }

  rescue => e
    Rails.logger.error "[NativeApple] Token verification error: #{e.class} - #{e.message}"
    nil
  end

  # Apple 공개키를 가져옴 (5분 캐시)
  def fetch_apple_public_keys
    cached = Rails.cache.read("apple_public_keys")
    return cached if cached

    uri = URI("https://appleid.apple.com/auth/keys")
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[NativeApple] Failed to fetch Apple keys: #{response.code}"
      return []
    end

    keys = JSON.parse(response.body)["keys"]
    Rails.cache.write("apple_public_keys", keys, expires_in: 5.minutes)
    keys
  end

  # JWK → RSA 공개키 변환 (OpenSSL 3.x 호환)
  def build_rsa_key(key_data)
    n_data = Base64.urlsafe_decode64(key_data["n"])
    e_data = Base64.urlsafe_decode64(key_data["e"])

    # RSAPublicKey ASN1 시퀀스
    rsa_public_key = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(n_data, 2)),
      OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(e_data, 2))
    ])

    # SubjectPublicKeyInfo DER로 감싸서 OpenSSL에서 인식 가능하게 함
    subject_public_key_info = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::Sequence.new([
        OpenSSL::ASN1::ObjectId.new("rsaEncryption"),
        OpenSSL::ASN1::Null.new(nil)
      ]),
      OpenSSL::ASN1::BitString.new(rsa_public_key.to_der)
    ]).to_der

    OpenSSL::PKey::RSA.new(subject_public_key_info)
  end
end
