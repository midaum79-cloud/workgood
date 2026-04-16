user = User.new(name: "Test", team_name: "Mock", role: "mock", phone: "010", email: "test@test.com", password: "password")
ac = ApplicationController.new
ac.instance_variable_set(:@_current_user, user)
ac.request = ActionDispatch::TestRequest.create
av = ActionView::Base.with_empty_template_cache.with_view_paths(ActionController::Base.view_paths, {}, ac)
def av.current_user; User.new(name: "Test", team_name: "Mock", role: "mock", phone: "010"); end
begin
  av.render(file: 'app/views/my_account/documents.html.erb')
  puts "SUCCESS!"
rescue => e
  puts "ERROR: #{e.class}"
  puts e.message
  puts e.backtrace.first(15)
end
