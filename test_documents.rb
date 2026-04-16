class ApplicationController < ActionController::Base
  def require_login
    true
  end
  def current_user
    User.first || User.new(name: "Test", team_name: "Mocking", role: "Manager", phone: "010-1111-2222")
  end
  before_action :require_login
  helper_method :current_user
end
begin
  env = Rack::MockRequest.env_for("/my_account/documents", method: "GET")
  status, headers, response = Rails.application.call(env)
  if status == 500
    puts "500 ERROR CAUGHT!"
    # The last exception is stored in env['action_dispatch.exception']
    exception = env['action_dispatch.exception']
    if exception
      puts "#{exception.class}: #{exception.message}"
      puts exception.backtrace.first(15)
    end
  else
    puts "SUCCESS: #{status}"
  end
rescue => e
  puts "CRASH: #{e.class} - #{e.message}"
  puts e.backtrace.first(15)
end
