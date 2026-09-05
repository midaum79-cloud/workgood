require 'net/http'
require 'json'
require 'dotenv/load'

rc_key = ENV["REVENUECAT_SECRET_KEY"]

# Let's try to query the subscribers list? RevenueCat doesn't have an endpoint to list all subscribers easily.
# But we can query the latest users in our local DB if we have a production dump?
# No, we don't have the production DB.
