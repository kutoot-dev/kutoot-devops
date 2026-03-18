# -----------------------------------------------------------------------------
# S3 Bucket for Laravel uploads (kutoot-backend)
# Public read for GetObject, CORS for frontend/backend
# -----------------------------------------------------------------------------

locals {
  name   = "${var.project_name}-${var.environment}"
  bucket = "${var.project_name}-backend"
}

resource "aws_s3_bucket" "laravel" {
  bucket = local.bucket

  tags = {
    Name = "${local.name}-uploads"
  }
}

# Allow bucket policy (required for public read)
resource "aws_s3_bucket_public_access_block" "laravel" {
  bucket = aws_s3_bucket.laravel.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# Public read for GetObject (backend/frontend can download)
resource "aws_s3_bucket_policy" "laravel" {
  bucket = aws_s3_bucket.laravel.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.laravel.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.laravel]
}

# CORS for frontend/backend uploads
resource "aws_s3_bucket_cors_configuration" "laravel" {
  bucket = aws_s3_bucket.laravel.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST"]
    allowed_origins = [
      "https://dev.kutoot.com",
      "https://www.kutoot.com",
      "https://frontend.kutoot.com",
      "https://main.d1m3jak1924r3d.amplifyapp.com",
      "http://localhost:3000",
      "http://localhost:8000",
      "http://dev.kutoot.com",
      "http://main.d1m3jak1924r3d.amplifyapp.com"
    ]
    expose_headers = ["ETag"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_versioning" "laravel" {
  bucket = aws_s3_bucket.laravel.id

  versioning_configuration {
    status = "Enabled"
  }
}
