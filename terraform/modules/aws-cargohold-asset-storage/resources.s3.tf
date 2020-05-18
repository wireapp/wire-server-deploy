resource "aws_s3_bucket" "asset_storage" {
  bucket = "${var.environment}-${var.bucket_name}"
  acl    = "private"
  region = var.region
}
