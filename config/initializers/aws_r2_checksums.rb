# Cloudflare R2는 AWS S3와 달리 다중 체크섬 헤더를 지원하지 않습니다.
# aws-sdk-s3 v1.170+ 에서 자동 체크섬 계산이 추가되었으므로 이를 비활성화합니다.
# "You can only specify one non-default checksum at a time" 에러 방지.
if defined?(Aws)
  Aws.config.update({
    request_checksum_calculation: "when_required",
    response_checksum_validation: "when_required"
  })
end
