require 'net/http'
require 'uri'
require 'json'

text = "고객: 홍길동\n업체: 믿음인테리어\n연락처: 010-1234-5678\n주소: 서울시 강남구 테헤란로 123 101동 202호"
prompt = <<~PROMPT
  사용자가 전달한 문자(텍스트)에서 인테리어 공사 관련 고객정보를 추출해주세요.
  추출할 정보:
  - 캘린더명(또는 고객명/현장명/일내용)
  - 업체명
  - 연락처
  - 주소 (상세주소 포함)

  ★ 규칙:
  1. 추출 불가능한 정보는 빈 문자열("")로 반환하세요.
  2. "고객명"이 없고 "업체명"만 있다면 고객명에 업체명을 넣어도 좋습니다.
  3. 반드시 다음과 같은 순수 JSON 형식으로 응답하세요. 마크다운(```json)이나 다른 설명은 절대 추가하지 마세요.
  {
    "project_name": "추출한 캘린더명 또는 고객명/현장명",
    "client_name": "추출한 업체명",
    "client_phone": "추출한 연락처 (형식: 010-0000-0000 등)",
    "address": "추출한 주소 (상세주소 포함)"
  }
PROMPT

uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{ENV['GEMINI_API_KEY']}")
request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
request.body = {
  "contents" => [
    { "role" => "user", "parts" => [
      { "text" => prompt },
      { "text" => "분석할 텍스트: " + text }
    ]}
  ]
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  http.request(request)
end

puts response.code
puts response.body
