namespace :subscriptions do
  desc "Check and downgrade expired subscriptions to free plan"
  task expire: :environment do
    puts "Starting subscription expiration check... [#{Time.current}]"
    
    # 만료일이 지났으면서, 유료 요금제(free가 아닌)를 사용 중인 사용자 탐색
    expired_users = User.where.not(subscription_plan: "free")
                        .where("subscription_expires_at < ?", Time.current)
    
    count = 0
    expired_users.find_each do |user|
      old_plan = user[:subscription_plan]
      # subscription_plan 호출 시 만료되었으면 자동으로 sync_revenuecat_subscription이 실행됨
      # 갱신되었으면 새로운 플랜이, 갱신이 안 되었으면 자동으로 "free"로 강등 처리됨
      new_plan = user.subscription_plan
      
      if new_plan == "free"
        count += 1
        puts "[User ID: #{user.id}] #{user.email} 님의 요금제가 실제로 만료되어 free 요금제로 강등되었습니다."
      else
        puts "[User ID: #{user.id}] #{user.email} 님의 요금제가 RevenueCat을 통해 #{new_plan}으로 자동 갱신되었습니다."
      end
    end
    
    puts "Finished subscription expiration check. Total #{count} users processed."
  end

  desc "Sync all recently expired or historically subscribed users with RevenueCat to restore incorrect downgrades"
  task sync_all: :environment do
    puts "Starting RevenueCat subscription restoration sync... [#{Time.current}]"
    
    # 과거에 구독 이력이 있었으나 현재 무료 요금제로 되어 있는 유저 탐색
    # (subscription_expires_at이 설정되어 있었으나 현재 무료인 유저)
    candidate_users = User.where(subscription_plan: "free").where.not(subscription_expires_at: nil)
    
    puts "Found #{candidate_users.count} potential users to sync..."
    
    restored_count = 0
    candidate_users.find_each do |user|
      puts "[User ID: #{user.id}] #{user.email} 님의 구독 정보를 RevenueCat과 연동하는 중..."
      
      # sync_revenuecat_subscription 메서드를 직접 호출하여 RevenueCat 상태 체크
      # 만약 활성 구독이 확인되면 premium/standard로 복원됨
      synced_plan = user.sync_revenuecat_subscription
      
      if synced_plan
        restored_count += 1
        puts "  -> 🎉 복원 성공! #{synced_plan} 요금제로 복구되었습니다. (만료일: #{user.subscription_expires_at})"
      else
        puts "  -> 갱신된 구독 정보 없음."
      end
    end
    
    puts "Finished subscription sync. Total #{restored_count} users restored."
  end
end
