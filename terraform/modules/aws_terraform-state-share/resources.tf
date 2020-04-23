# create an S3 bucket to store the state file in
resource "aws_s3_bucket" "terraform-state-storage" {
  bucket = var.bucket_name

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "S3 Remote Terraform State Store"
  }
}

# create a dynamodb table for locking the state file
resource "aws_dynamodb_table" "terraform-state-lock" {
  name           = var.table_name
  hash_key       = "LockID"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "DynamoDB Terraform State Lock Table"
  }
}
