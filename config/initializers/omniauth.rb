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
      provider :apple,
        ENV["APPLE_CLIENT_ID"],
        "",
        {
          scope: "email name",
          team_id: ENV["APPLE_TEAM_ID"],
          key_id: ENV["APPLE_KEY_ID"],
          pem: ENV["APPLE_PRIVATE_KEY"]&.gsub("\\n", "\n")
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
end

