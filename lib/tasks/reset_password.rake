namespace :users do
  desc "Reset a user's password: rake users:reset_password EMAIL=user@example.com PASSWORD=newpassword"
  task reset_password: :environment do
    email = ENV["EMAIL"]
    password = ENV["PASSWORD"]

    abort "Usage: rake users:reset_password EMAIL=user@example.com PASSWORD=newpassword" if email.blank? || password.blank?

    user = User.find_by(email: email.strip.downcase)
    abort "User not found: #{email}" unless user

    user.update!(password: password, password_confirmation: password)
    puts "✅ Password reset for #{user.email} (#{user.name})"
  end
end
