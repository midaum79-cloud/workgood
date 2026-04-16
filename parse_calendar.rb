begin
  ActionController::Base.new.view_context.render(template: 'projects/calendar')
rescue => e
  if e.is_a?(ActionView::Template::Error) && e.cause.is_a?(SyntaxError)
    puts "REAL-SYNTAX-ERROR: #{e.cause.message}"
  else
    puts "SUCCESS-SYNTAX: #{e.class} - #{e.message}"
  end
end
