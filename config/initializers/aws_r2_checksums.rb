# Cloudflare R2는 AWS S3와 달리 다중 체크섬 헤더를 지원하지 않습니다.
# aws-sdk-s3 v1.170+ 에서 자동 체크섬 계산이 추가되었으므로 이를 비활성화합니다.
# "You can only specify one non-default checksum at a time" 에러 방지.

# 방법 1: 환경변수 (AWS SDK가 로드되기 전에 설정)
ENV['AWS_REQUEST_CHECKSUM_CALCULATION'] ||= 'WHEN_REQUIRED'
ENV['AWS_RESPONSE_CHECKSUM_VALIDATION'] ||= 'WHEN_REQUIRED'

# 방법 2: Aws.config 직접 설정
if defined?(Aws)
  Aws.config.update({
    request_checksum_calculation: "when_required",
    response_checksum_validation: "when_required"
  })
end

# 방법 3: Rails 초기화 완료 후 재설정 (가장 늦게 로드되는 시점)
Rails.application.config.after_initialize do
  if defined?(Aws)
    Aws.config.update({
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    })
  end
end
