resource "aws_s3_bucket" "asset_storage" {
  bucket = "${random_string.bucket.keepers.env}-${random_string.bucket.keepers.name}-cargohold-${random_string.bucket.result}"
  acl    = "private"
  region = var.region
}

resource "random_string" "bucket" {
  length = 8
  lower = true
  upper = false
  number = true
  special = false

  keepers = {
    env = var.environment
    name = var.bucket_name
  }
}
