resource "aws_iam_user" "cargohold" {
  name          = "${var.environment}-cargohold-full-access"
  force_destroy = true
}

resource "aws_iam_access_key" "cargohold" {
  user = aws_iam_user.cargohold.name
}

# Create a specific user that can be used to access the bucket and the files within
#
resource "aws_iam_user_policy" "cargohold" {
  name = "${var.environment}-cargohold-full-access-policy"
  user = aws_iam_user.cargohold.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "s3:GetObject",
                  "s3:ListBucket",
                  "s3:PutObject",
                  "s3:DeleteObject"
              ],
              "Resource": [
                  "${aws_s3_bucket.asset_storage.arn}/*",
                  "${aws_s3_bucket.asset_storage.arn}"
              ]
          }
      ]
  }
  EOP
}
