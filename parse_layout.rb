begin
  ActionController::Base.new.view_context.render(template: 'layouts/application')
rescue => e
  if e.is_a?(ActionView::Template::Error)
    cause = e.cause
    if cause && cause.is_a?(SyntaxError)
      puts "REAL-SYNTAX-ERROR: #{cause.message}"
    else
      puts "RUNTIME-ERROR: #{cause.class} - #{cause.message}"
    end
  else
    puts "OTHER-ERROR: #{e.class} - #{e.message}"
  end
end
