begin
  Rails.application.config.middleware.use OmniAuth::Builder do
    # Google OAuth2
    if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
      provider :google_oauth2,
        ENV["GOOGLE_CLIENT_ID"],
        ENV["GOOGLE_CLIENT_SECRET"],
        {
          scope: "email,profile",
          prompt: "select_account",
          image_aspect_ratio: "square",
          image_size: 200
        }
      Rails.logger.info "[OmniAuth] Google OAuth2 enabled"
    else
      Rails.logger.warn "[OmniAuth] GOOGLE_CLIENT_ID/SECRET not set — Google login disabled"
    end

    # Apple Sign In
    if ENV["APPLE_CLIENT_ID"].present? && ENV["APPLE_TEAM_ID"].present?
      apple_pem = ENV["APPLE_PRIVATE_KEY"]
      if apple_pem.present?
        apple_pem = apple_pem.gsub("\\n", "\n")
        unless apple_pem.include?("-----BEGIN")
          apple_pem = "-----BEGIN PRIVATE KEY-----\n#{apple_pem.strip}\n-----END PRIVATE KEY-----"
        end
        Rails.logger.info "[OmniAuth] Apple PEM key loaded (#{apple_pem.bytesize} bytes)"

        begin
          test_key = OpenSSL::PKey::EC.new(apple_pem)
          Rails.logger.info "[OmniAuth] Apple EC key valid! Group: #{test_key.group.curve_name}"
        rescue => key_err
          Rails.logger.error "[OmniAuth] Apple EC key INVALID: #{key_err.message}"
        end
      else
        Rails.logger.error "[OmniAuth] APPLE_PRIVATE_KEY is empty!"
      end

      provider :apple,
        ENV["APPLE_CLIENT_ID"],
        "",
        {
          scope: "email name",
          team_id: ENV["APPLE_TEAM_ID"],
          key_id: ENV["APPLE_KEY_ID"],
          pem: apple_pem,
          authorized_client_ids: [ENV["APPLE_CLIENT_ID"], "com.workgood.app"]
        }
      Rails.logger.info "[OmniAuth] Apple Sign In enabled"
    else
      Rails.logger.warn "[OmniAuth] APPLE_CLIENT_ID/TEAM_ID not set — Apple login disabled"
    end
  end

  OmniAuth.config.allowed_request_methods = [ :post, :get ]
  OmniAuth.config.silence_get_warning = true
rescue => e
  Rails.logger.error "[OmniAuth] Init error: #{e.message}"
  Rails.logger.error "[OmniAuth] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
end

# ── Apple Strategy monkey-patch ──
# omniauth-apple 1.4.0의 client_id 메소드가 콜백 단계에서 nil을 반환하는 버그 수정
# 원래 코드: id_info[:aud]를 authorized_client_ids에서 찾지 못하면 nil 반환
# 수정: 항상 options.client_id를 반환하도록 변경
module OmniAuth
  module Strategies
    class Apple < OmniAuth::Strategies::OAuth2
      private

      def client_id
        @client_id ||= options.client_id
      end

      def client_secret
        cid = client_id
        Rails.logger.info "[OmniAuth::Apple] Generating client_secret with sub=#{cid}, iss=#{options.team_id}, key_id=#{options.key_id}"

        jwt = JSON::JWT.new(
          iss: options.team_id,
          aud: 'https://appleid.apple.com',
          sub: cid,
          iat: Time.now,
          exp: Time.now + 60
        )
        jwt.kid = options.key_id
        signed = jwt.sign(private_key)
        secret = signed.to_s

        Rails.logger.info "[OmniAuth::Apple] client_secret generated (#{secret&.length} chars)"
        secret
      rescue => e
        Rails.logger.error "[OmniAuth::Apple] client_secret generation FAILED: #{e.class} - #{e.message}"
        Rails.logger.error "[OmniAuth::Apple] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
        raise
      end
    end
  end
end

