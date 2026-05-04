namespace :users do
  desc "Downgrade all users to free except admin and one specific user"
  task :downgrade_to_free, [:identifier] => :environment do |t, args|
    identifier = args[:identifier]
    
    if identifier.blank?
      puts "오류: 제외할 실제 유료 결제 유저의 이메일이나 ID(숫자)를 입력해주세요."
      puts "사용법: rails users:downgrade_to_free[유저이메일@예시.com] 또는 rails users:downgrade_to_free[2]"
      exit
    end

    # 식별자가 숫자인 경우 ID로 검색, 아니면 이메일로 검색
    genuine_user = if identifier.to_s.match?(/^\d+$/)
                     User.find_by(id: identifier.to_i)
                   else
                     User.find_by(email: identifier)
                   end

    if genuine_user.nil?
      puts "오류: 해당 이메일이나 ID(#{identifier})를 가진 유저를 찾을 수 없습니다."
      exit
    end

    puts "✅ 보호할 찐 유료 구독자 확인됨: #{genuine_user.email} (ID: #{genuine_user.id})"

    admin_email = "midaum79@gmail.com"
    
    users_to_downgrade = User.where(subscription_plan: ['premium', 'standard'])
                             .where.not(id: genuine_user.id)
                             .where.not(email: admin_email)
                             
    count = users_to_downgrade.count
    puts "총 #{count}명의 테스트 유저를 무료 플랜으로 전환합니다..."
    
    users_to_downgrade.update_all(
      subscription_plan: 'free', 
      subscription_expires_at: nil, 
      billing_key: nil
    )
    
    puts "완료되었습니다! #{count}명이 무료 플랜으로 강제 전환되었습니다."
  end
end
