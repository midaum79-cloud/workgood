# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# 크론 작업의 로그를 저장할 파일 지정
set :output, "log/cron.log"
env :PATH, ENV['PATH']

# 매 1시간마다 만료된 구독자 정리 Rake Task 실행
every 1.hour do
  rake "subscriptions:expire"
end

# 매일 자정(0시)에 한 번씩 돌리시려면 아래 코드를 사용하세요 (주석 해제)
# every 1.day, at: '12:00 am' do
#   rake "subscriptions:expire"
# end
