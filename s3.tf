# S3 Bucket for Extractor Results Storage

resource "aws_s3_bucket" "extractor_results" {
  count = var.create_s3_bucket ? 1 : 0
  bucket = "${var.project_name}-extractor-results"

  tags = {
    Name      = "${var.project_name}-extractor-results"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "extractor_results" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.extractor_results[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "extractor_results" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.extractor_results[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access block (keep private)
resource "aws_s3_bucket_public_access_block" "extractor_results" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.extractor_results[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy - delete old results after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "extractor_results" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.extractor_results[0].id

  rule {
    id     = "delete-old-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Output bucket name
output "s3_bucket_name" {
  description = "S3 bucket name for extractor results"
  value       = var.create_s3_bucket ? aws_s3_bucket.extractor_results[0].id : null
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = var.create_s3_bucket ? aws_s3_bucket.extractor_results[0].arn : null
}

