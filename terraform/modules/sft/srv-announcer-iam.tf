resource "aws_iam_user" "srv-announcer" {
  name          = "${var.environment}-srv-announcer"
  force_destroy = true # TODO: Add a comment explaining this. Does this mean
                       # changing this user will make existing srv announcements
                       # fail?
}

resource "aws_iam_access_key" "srv-announcer" {
  user = aws_iam_user.srv-announcer.name
}

# NOTE: Does not configure permissions for GeoLocation, because they are not
# needed by the srv-announcer DOCS:
# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/r53-api-permissions-ref.html#required-permissions-resource-record-sets
#
resource "aws_iam_user_policy" "srv-announcer-recordsets" {
  name = "${var.environment}-srv-announcer-route53-recordsets-policy"
  user = aws_iam_user.srv-announcer.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "route53:ChangeResourceRecordSets",
                  "route53:ListResourceRecordSets"
              ],
              "Resource": [
                  "arn:aws:route53:::hostedzone/${data.aws_route53_zone.sft_zone.zone_id}"
              ]
          }
      ]
  }
  EOP
}

resource "aws_iam_user_policy" "srv-announcer-getrecordchanges" {
  name = "${var.environment}-srv-announcer-route53-getrecordchanges-policy"
  user = aws_iam_user.srv-announcer.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "route53:GetChange",
                  "route53:ListHostedZonesByName"
              ],
              "Resource": [
                  "*"
              ]
          }
      ]
  }
  EOP
}
