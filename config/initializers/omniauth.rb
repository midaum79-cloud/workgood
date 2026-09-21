begin
  # OmniAuth OAuth2 몽키패치: 세션 유실 방지를 위해 state 파라미터에 app_nonce 주입
  module OmniAuth
    module Strategies
      class OAuth2
        def authorize_params
          options.authorize_params[:state] = SecureRandom.hex(24)
          
          # 요청 파라미터에 app_nonce가 있으면 state 끝에 붙여서 구글로 보냄
          if request.params["app_nonce"].present?
            options.authorize_params[:state] += "___#{request.params["app_nonce"]}"
          end

          if OmniAuth.config.test_mode
            @env ||= {}
            @env["rack.session"] ||= {}
          end

          params = options.authorize_params
                          .merge(options_for("authorize"))
                          .merge(pkce_authorize_params)

          session["omniauth.pkce.verifier"] = options.pkce_verifier if options.pkce
          session["omniauth.state"] = params[:state]

          params
        end
      end
    end
  end

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
          image_size: 200,
          provider_ignores_state: true
        }
      Rails.logger.info "[OmniAuth] Google OAuth2 enabled"
    else
      Rails.logger.warn "[OmniAuth] GOOGLE_CLIENT_ID/SECRET not set — Google login disabled"
    end
  end

  OmniAuth.config.allowed_request_methods = [ :post, :get ]
  OmniAuth.config.silence_get_warning = true
rescue => e
  Rails.logger.error "[OmniAuth] Init error: #{e.message}"
  Rails.logger.error "[OmniAuth] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
end
