require 'aws-sdk-s3'
Aws.config.update(s3: { compute_checksums: false })
