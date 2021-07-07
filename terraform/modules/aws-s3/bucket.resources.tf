resource "random_string" "suffix" {
  count = var.bucketPrefix != null ? 1 : 4

  length = 6

  lower   = true
  upper   = false
  number  = true
  special = false

  keepers = {
    bucketPrefix = var.bucketPrefix
  }
}
