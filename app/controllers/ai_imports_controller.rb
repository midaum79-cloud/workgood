class AiImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_ai_quota

  # POST /projects/:project_id/ai_imports/analyze
  # POST /ai_imports/analyze
  def analyze
    require "base64"
    @project = current_user.projects.find_by(id: params[:project_id]) if params[:project_id].present?

    files = params[:files] || (params[:file].present? ? [ params[:file] ] : [])
    if files.empty?
      return render json: { error: "업로드된 파일이 없습니다." }, status: :bad_request
    end

    begin
      prompt = ""
      if @project
        # 1. Get existing project work processes to map
        existing_processes = @project.work_processes.select(:id, :process_name).map do |wp|
          { id: wp.id, name: wp.process_name }
        end

        # 2. Prepare Gemini Prompt
        prompt = <<~PROMPT
          첨부된 이미지들은 인테리어 공정표(일정표)입니다. 다수의 이미지일 경우 연결된 하나의 표라고 생각하고 분석해주세요.
          이 이미지들에서 각 진행 항목의 '날짜(Date)'와 '작업 내용(공정명, 내용)'을 추출해주세요.

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
      else
        prompt = <<~PROMPT
          첨부된 이미지들은 인테리어 공정표(일정표)입니다. 다수의 이미지일 경우 연결된 하나의 표라고 생각하고 분석해주세요.
          이 이미지들에서 각 진행 항목의 '날짜(Date)'와 '작업 내용(공정명, 내용)'을 추출해주세요.

          조건 1: 연도가 명시되어 있지 않다면 올해(#{Date.current.year}년)로 간주합니다. 날짜 형식은 YYYY-MM-DD 로 통일해주세요.
          조건 2: 원문 그대로의 텍스트(공정명)와 해당 날짜를 추출하세요.

          결과는 반드시 다음과 같은 순수 JSON 배열 형식으로만 응답해야 합니다. 마크다운 백틱(```json)이나 다른 설명은 절대 추가하지 마세요.
          [
            { "date": "YYYY-MM-DD", "raw_text": "원문 공정명" },
            ...
          ]
        PROMPT
      end


      # 3. Direct API Call using Net::HTTP
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{ENV['GEMINI_API_KEY']}")
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      
      api_parts = [ { "text" => prompt } ]

      files.first(3).each do |file|
        mime_type = file.content_type
        base64_image = Base64.strict_encode64(file.read)
        api_parts << { 
          "inlineData" => { 
            "mimeType" => mime_type, 
            "data" => base64_image 
          } 
        }
      end

      request.body = {
        "contents" => [
          { "role" => "user", "parts" => api_parts }
        ]
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_response = JSON.parse(response.body)
      
      if response.code.to_i != 200
        raise "Gemini API Error: #{parsed_response.dig('error', 'message')}"
      end

      # 5. Parse Response
      raw_json = parsed_response.dig("candidates", 0, "content", "parts", 0, "text") || "[]"

      # Clean up potential markdown formatting
      clean_json = raw_json.sub(/\A```json\s*/, '').sub(/\s*```\z/, '').strip
      

      parsed_data = JSON.parse(clean_json)

      render json: { success: true, data: parsed_data }

    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parsing Error: #{e.message}\nRaw Text: #{raw_json}"
      render json: { error: "AI 응답을 해석하는 데 실패했습니다. 다시 시도해주세요." }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "[AI_IMPORT_ERROR] #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: "서버 응답 오류: #{e.message}" }, status: :internal_server_error
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
