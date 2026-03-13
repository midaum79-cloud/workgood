class AiImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_premium!

  # POST /projects/:project_id/ai_imports/analyze
  def analyze
    @project = current_user.projects.find(params[:project_id])

    unless params[:file].present?
      return render json: { error: "업로드된 파일이 없습니다." }, status: :bad_request
    end

    begin
      # 1. Get existing project work processes to map
      existing_processes = @project.work_processes.select(:id, :process_name).map do |wp|
        { id: wp.id, name: wp.process_name }
      end

      # 2. Prepare Gemini Prompt
      prompt = <<~PROMPT
        첨부된 이미지는 인테리어 공정표(일정표)입니다.
        이 이미지에서 각 진행 항목의 '날짜(Date)'와 '작업 내용(공정명, 내용)'을 추출해주세요.

        조건 1: 연도가 명시되어 있지 않다면 올해(#{Date.current.year}년)로 간주합니다. 날짜 형식은 YYYY-MM-DD 로 통일해주세요.
        조건 2: 추출한 '작업 내용(raw_text)'을 다음 제공된 '기존 현장 공정 리스트'와 비교하여, 의미가 일치하거나 가장 유사한 항목의 ID(matched_process_id)를 찾아주세요.#{' '}
        만약 매칭되는 공정이 없다면 matched_process_id는 null로 비워두세요.

        기존 현장 공정 리스트:
        #{existing_processes.to_json}

        결과는 반드시 다음과 같은 순수 JSON 배열 형식으로만 응답해야 합니다. 마크다운 백틱(```json)이나 다른 설명은 절대 추가하지 마세요.
        [
          { "date": "YYYY-MM-DD", "raw_text": "원문 공정명", "matched_process_id": 123 },
          ...
        ]
      PROMPT

      # 3. Initialize Gemini
      client = Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: ENV["GEMINI_API_KEY"]
        },
        options: { model: "gemini-1.5-flash", server_sent_events: true }
      )

      # 4. Upload and Call API
      file = params[:file]
      mime_type = file.content_type
      base64_image = Base64.strict_encode64(file.read)

      response = client.generate_content({
        contents: [
          { role: "user", parts: [
              { text: prompt },
              { inlineData: { mimeType: mime_type, data: base64_image } }
            ]
          }
        ]
      })

      # 5. Parse Response
      raw_json = response.dig("candidates", 0, "content", "parts", 0, "text") || "[]"

      # Clean up potential markdown formatting
      clean_json = raw_json.gsub(/```json\n?/, "").gsub(/```/, "").strip

      parsed_data = JSON.parse(clean_json)

      render json: { success: true, data: parsed_data }

    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parsing Error: #{e.message}\nRaw Text: #{raw_json}"
      render json: { error: "AI 응답을 해석하는 데 실패했습니다. 다시 시도해주세요." }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Gemini API Error: #{e.message}"
      render json: { error: "AI 분석 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  # POST /projects/:project_id/ai_imports/commit
  def commit
    @project = current_user.projects.find(params[:project_id])
    items = params[:items] || []

    success_count = 0

    ActiveRecord::Base.transaction do
      items.each do |item|
        # Only process items that have a matched process AND a valid date
        if item[:matched_process_id].present? && item[:date].present?
          work_process = @project.work_processes.find_by(id: item[:matched_process_id])

          if work_process
            WorkDay.find_or_create_by!(
              work_process: work_process,
              work_date: item[:date]
            )
            success_count += 1
          end
        end
      end
    end

    render json: { success: true, count: success_count }
  rescue => e
    render json: { error: "등록 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
  end

  private

  def check_premium!
    unless current_user.premium?
      render json: { error: "프리미엄 요금제 전용 기능입니다." }, status: :forbidden
    end
  end
end
