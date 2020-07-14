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

# Create a policy that can be applied to a role, and can be used to access the bucket and the files within.
resource "aws_iam_policy" "cargohold-s3" {
  name = "${var.environment}-cargohold-s3"
  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": "s3:*",
              "Resource": "*"
          }
      ]
  }
  EOP
}

# Create an IAM role that can be applied to an instance, and can be used to access the bucket and the files within.
resource "aws_iam_role" "cargohold-s3" {
  name = "${var.environment}-cargohold-s3"
  description = "provide access to s3, for cargohold."
  assume_role_policy = <<-EOP
  {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Action": "sts:AssumeRole",
         "Principal": {
           "Service": "ec2.amazonaws.com"
         },
         "Effect": "Allow",
         "Sid": ""
       }
     ]
  }
  EOP
  tags = {
    Name        = "${var.environment}-cargohold-s3",
    Environment = "${var.environment}"
    Gateway     = "cargohold-s3"
  }
}


# attach our IAM policy to our IAM role.
resource "aws_iam_policy_attachment" "cargohold-s3-attach" {
  name       = "${var.environment}-cargohold-s3"
  roles       = [aws_iam_role.cargohold-s3.name]
  policy_arn = aws_iam_policy.cargohold-s3.arn
}
