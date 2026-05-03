# Cloudflare R2는 AWS S3와 달리 다중 체크섬 헤더를 지원하지 않습니다.
# aws-sdk-s3 v1.170+ 에서 자동 체크섬 계산이 추가되었으므로 이를 비활성화합니다.
# "You can only specify one non-default checksum at a time" 에러 방지.
#
# 환경변수만 사용 — Aws.config.update에 이 옵션을 넣으면
# 서명(SignatureDoesNotMatch) 충돌이 발생할 수 있으므로 ENV만 사용합니다.
ENV["AWS_REQUEST_CHECKSUM_CALCULATION"] ||= "WHEN_REQUIRED"
ENV["AWS_RESPONSE_CHECKSUM_VALIDATION"] ||= "WHEN_REQUIRED"
