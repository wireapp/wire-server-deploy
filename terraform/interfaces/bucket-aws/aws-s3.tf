module "bucket" {
  source = "./../../modules/aws-s3"

  bucketPrefix = var.name
  accessControl = var.is_public ? "public-read" : "private"
}
