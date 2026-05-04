namespace :subscriptions do
  desc "Check and downgrade expired subscriptions to free plan"
  task expire: :environment do
    puts "Starting subscription expiration check... [#{Time.current}]"
    
    # 만료일이 지났으면서, 유료 요금제(free가 아닌)를 사용 중인 사용자 탐색
    expired_users = User.where.not(subscription_plan: "free")
                        .where("subscription_expires_at < ?", Time.current)
    
    count = 0
    expired_users.find_each do |user|
      # 콜백 없이 DB 업데이트로 빠르게 처리 및 만료일 초기화
      user.update_columns(
        subscription_plan: "free",
        subscription_expires_at: nil
      )
      count += 1
      puts "[User ID: #{user.id}] #{user.email} 님의 요금제가 만료되어 free 요금제로 강등 및 만료일 초기화 완료."
    end
    
    puts "Finished subscription expiration check. Total #{count} users downgraded."
  end
end
