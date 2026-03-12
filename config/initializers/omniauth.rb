begin
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :google_oauth2,
        ENV["GOOGLE_CLIENT_ID"],
        ENV["GOOGLE_CLIENT_SECRET"],
        {
          scope: "email,profile",
          prompt: "select_account",
          image_aspect_ratio: "square",
          image_size: 200
        }
    end
    OmniAuth.config.allowed_request_methods = [ :post, :get ]
    OmniAuth.config.silence_get_warning = true
    Rails.logger.info "[OmniAuth] Google OAuth2 enabled"
  else
    Rails.logger.warn "[OmniAuth] GOOGLE_CLIENT_ID/SECRET not set — Google login disabled"
  end
rescue => e
  Rails.logger.error "[OmniAuth] Init error: #{e.message}"
end
