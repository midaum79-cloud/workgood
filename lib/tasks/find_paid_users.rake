namespace :users do
  desc "Find genuine paid users"
  task find_paid_users: :environment do
    puts "=== 실제 결제 기록(SubscriptionPayment)이 있는 유저 ==="
    paid_users = User.joins(:subscription_payments).distinct
    if paid_users.any?
      paid_users.each do |user|
        puts "- 이메일: #{user.email} (가입일: #{user.created_at.strftime('%Y-%m-%d')})"
      end
    else
      puts "결제 기록이 있는 유저가 없습니다."
    end

    puts "\n=== 결제 수단(카드 등)이 등록된 유저 (빌링키 보유) ==="
    billing_users = User.where.not(billing_started_at: nil)
    if billing_users.any?
      billing_users.each do |user|
        puts "- 이메일: #{user.email} (결제시작일: #{user.billing_started_at.strftime('%Y-%m-%d')})"
      end
    else
      puts "결제 수단이 등록된 유저가 없습니다."
    end
  end
end
