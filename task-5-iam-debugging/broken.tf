variable "broken_account_a_id" {
  type    = string
  default = "000000000000"
}

variable "broken_bucket_name" {
  type    = string
  default = "company-production-data"
}

data "aws_iam_policy_document" "broken_role_c_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.broken_account_a_id}:user/roleB"]
    }
  }
}

resource "aws_iam_role" "broken_role_c" {
  name               = "roleC-broken-example"
  assume_role_policy = data.aws_iam_policy_document.broken_role_c_trust.json
}

resource "aws_iam_role_policy" "broken_role_c_s3" {
  name = "unrestricted-s3-broken-example"
  role = aws_iam_role.broken_role_c.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = "*"
    }]
  })
}
