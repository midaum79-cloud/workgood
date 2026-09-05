# 로컬 .env가 없는 운영 서버(Render 등)에서 API 키가 누락되는 것을 방지하기 위한 기본값 설정
ENV['GEMINI_API_KEY'] ||= 'AIzaSyA3HRoMIEN0tU4-kD-eF5YR6IwBieB16vI'
