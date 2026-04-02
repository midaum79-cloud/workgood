# Cloudflare R2는 AWS S3와 달리 다중 체크섬 헤더를 지원하지 않습니다.
# AWS SDK가 자동으로 CRC32 체크섬을 추가하는 것을 비활성화합니다.
# 빌드 시 aws-sdk가 로드되지 않을 수 있으므로 안전하게 처리합니다.
if defined?(Aws)
  Aws.config.update(s3: { compute_checksums: false })
end
