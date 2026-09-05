class AiRegistrationsController < ApplicationController
  before_action :require_login
  before_action :require_premium

  def analyze_text
    text = params[:text]
    if text.blank?
      return render json: { error: "분석할 텍스트가 없습니다." }, status: :bad_request
    end

    begin
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

      parsed_response = JSON.parse(response.body)

      if response.code.to_i != 200
        raise "Gemini API Error: #{parsed_response.dig('error', 'message')}"
      end

      raw_json = parsed_response.dig("candidates", 0, "content", "parts", 0, "text") || "{}"
      clean_json = raw_json.sub(/\A```json\s*/, "").sub(/\s*```\z/, "").strip
      
      parsed_data = JSON.parse(clean_json)

      render json: { success: true, data: parsed_data }
    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parsing Error: #{e.message}\nRaw Text: #{raw_json}"
      render json: { error: "AI 응답을 해석하는 데 실패했습니다. 다시 시도해주세요." }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "[AI_REGISTRATION_ERROR] #{e.message}"
      render json: { error: "AI 분석 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def require_premium
    unless current_user.premium?
      render json: { error: "프리미엄 플랜 전용 기능입니다." }, status: :forbidden
    end
  end
end
