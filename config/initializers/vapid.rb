# VAPID keys for Web Push notifications
# Set VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY in environment variables on Render

VAPID_PUBLIC_KEY = ENV.fetch("VAPID_PUBLIC_KEY", "")
VAPID_PRIVATE_KEY = ENV.fetch("VAPID_PRIVATE_KEY", "")
VAPID_EMAIL = ENV.fetch("VAPID_EMAIL", "mailto:midaum79@gmail.com")
