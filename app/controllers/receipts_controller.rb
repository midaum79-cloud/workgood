class ReceiptsController < ApplicationController
  before_action :require_login
  before_action :require_premium_for_receipts!

  def index
    @receipts = current_user.receipts.with_attached_image.order(receipt_date: :desc, created_at: :desc)
    
    # 그룹화 및 월별 총액 계산
    @grouped_receipts = @receipts.group_by { |r| r.receipt_date.beginning_of_month }
  end

  def new
    @receipt = current_user.receipts.build
  end

  def create
    @receipt = current_user.receipts.build(receipt_params)
    if @receipt.save
      redirect_to receipts_path, notice: "영수증이 저장되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @receipt = current_user.receipts.find(params[:id])
    @receipt.destroy
    redirect_to receipts_path, notice: "영수증이 삭제되었습니다."
  end

  def analyze
    require "base64"
    file = params[:file]
    if file.blank?
      return render json: { error: "업로드된 파일이 없습니다." }, status: :bad_request
    end

    begin
      prompt = <<~PROMPT
        첨부된 이미지는 현장 업무용 결제 영수증입니다.
        이 이미지에서 다음 4가지 정보를 추출해주세요.

        1. date: 결제일자 (YYYY-MM-DD 형식). 연도가 명확하지 않으면 #{Date.current.year}년을 사용하세요.
        2. amount: 결제총액 (숫자만, 예: 12000). 금액을 찾을 수 없으면 0.
        3. store_name: 결제처(상호명). 가장 잘 보이는 상점을 적어주세요.
        4. category: 식대, 자재비, 공구, 주유비, 기타 중 가장 적합한 카테고리 하나를 선택하세요. (식당/카페/편의점 -> 식대, 철물점 -> 자재비/공구, 주유소 -> 주유비)

        반드시 아래와 같은 순수 JSON 형식으로만 응답하세요. 백틱(```json)이나 다른 설명은 절대 추가하지 마세요.
        {
          "date": "2024-03-10",
          "amount": 15000,
          "store_name": "제일철물",
          "category": "자재비"
        }
      PROMPT

      api_key = ENV['GEMINI_RECEIPT_API_KEY'].presence || ENV['GEMINI_API_KEY']
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{api_key}")
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      
      mime_type = file.content_type
      base64_image = Base64.strict_encode64(file.read)

      request.body = {
        "contents" => [
          { 
            "role" => "user", 
            "parts" => [
              { "text" => prompt },
              { "inlineData" => { "mimeType" => mime_type, "data" => base64_image } }
            ] 
          }
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
      clean_json = raw_json.sub(/\A```json\s*/, '').sub(/\s*```\z/, '').strip
      
      parsed_data = JSON.parse(clean_json)

      render json: { success: true, data: parsed_data }

    rescue => e
      Rails.logger.error "[RECEIPT_ANALYZE_ERROR] #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: "영수증 분석 중 서버 응답 오류가 발생했습니다. 이미지가 명확한지 확인해주세요." }, status: :internal_server_error
    end
  end

  private

  def receipt_params
    params.require(:receipt).permit(:receipt_date, :amount, :store_name, :category, :memo, :image)
  end

  def require_premium_for_receipts!
    unless current_user.premium? || User::TESTING_PERIOD
      redirect_to subscription_path, alert: "AI 스마트 영수증 관리는 프리미엄 요금제 전용 기능입니다. 💰"
    end
  end
end
