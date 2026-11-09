variable "fixed_account_a_id" {
  description = "Account A ID containing roleB."
  type        = string
  default     = "000000000000"
}

variable "fixed_bucket_name" {
  description = "The one bucket roleC is allowed to access."
  type        = string
  default     = "company-production-data"
}

data "aws_iam_policy_document" "role_c_trust" {
  statement {
    sid     = "TrustOnlyAccountARoleB"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.fixed_account_a_id}:role/roleB"]
    }
  }
}

resource "aws_iam_role" "role_c" {
  name               = "roleC-fixed-example"
  assume_role_policy = data.aws_iam_policy_document.role_c_trust.json
}

resource "aws_iam_role_policy" "role_c_s3" {
  name = "designated-bucket-only"
  role = aws_iam_role.role_c.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FullAccessToOneBucket"
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        "arn:aws:s3:::${var.fixed_bucket_name}",
        "arn:aws:s3:::${var.fixed_bucket_name}/*"
      ]
    }]
  })
}
