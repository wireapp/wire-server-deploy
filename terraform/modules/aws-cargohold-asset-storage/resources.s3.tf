resource "aws_s3_bucket" "asset_storage" {
  bucket = "${random_string.bucket.keepers.env}-${random_string.bucket.keepers.name}-cargohold-${random_string.bucket.result}"
  acl    = "private"
  region = var.region

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

}

resource "random_string" "bucket" {
  length  = 8
  lower   = true
  upper   = false
  number  = true
  special = false

  keepers = {
    env  = var.environment
    name = var.bucket_name
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = {
    Environment = var.environment
  }
}

data "aws_route_tables" "private" {
  vpc_id = var.vpc_id

  filter {
    name   = "association.subnet-id"
    values = var.subnet_ids
  }
}

# the routing table association that allows nodes to route traffic to the S3 endpoint.
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  for_each = { for k, v in data.aws_route_tables.private.ids : v => v }

  route_table_id  = each.value
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
