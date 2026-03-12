if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      {
        scope: "email, profile",
        prompt: "select_account",
        image_aspect_ratio: "square",
        image_size: 200
      }
  end
else
  Rails.logger.warn "[OmniAuth] GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET not set — Google login disabled"
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
