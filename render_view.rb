class User < ApplicationRecord
end

av = ActionController::Base.new.view_context
av.instance_variable_set(:@virtual_path, "my_account/documents")

# Mock current_user
user = User.new(name: "Test", team_name: "Mock", role: "mock", phone: "010", bank_name: "신한은행", bank_account_number: "123", bank_account_holder: "Me")
def user.premium?; true; end

av.class.module_eval do
  def current_user; User.first || User.new(name: "Test", team_name: "Mock", role: "mock", phone: "010"); end
  def update_my_account_documents_path; "/dummy"; end
  def protect_against_forgery?; false; end
  def notice; nil; end
  def alert; nil; end
  def form_authenticity_token; "token"; end
end

begin
  puts av.render(template: 'my_account/documents')
  puts "SUCCESS-RENDER"
rescue => e
  puts "VIEW-CRASH: #{e.class} - #{e.message}"
  puts e.backtrace.first(15)
end
