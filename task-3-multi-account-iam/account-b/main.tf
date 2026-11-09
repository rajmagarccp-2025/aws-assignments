module "production_data_bucket" {
  source = "../../modules/secure-s3-bucket"

  bucket_name       = var.production_bucket_name
  enable_versioning = true
  tags = {
    Name        = var.production_bucket_name
    Environment = var.environment
    Owner       = var.owner
  }
}

data "aws_iam_policy_document" "role_c_trust" {
  statement {
    sid     = "TrustOnlyAccountARoleB"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
    }
  }
}

resource "aws_iam_role" "role_c" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.role_c_trust.json

  tags = {
    Name        = "roleC"
    Environment = var.environment
    Owner       = var.owner
  }
}

data "aws_iam_policy_document" "role_c_s3_access" {
  statement {
    sid    = "BucketOperations"
    effect = "Allow"
    actions = var.enable_assignment_full_s3_access ? ["s3:*"] : [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [module.production_data_bucket.arn]
  }

  statement {
    sid    = "ObjectOperations"
    effect = "Allow"
    actions = var.enable_assignment_full_s3_access ? ["s3:*"] : [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${module.production_data_bucket.arn}/*"]
  }
}

resource "aws_iam_role_policy" "role_c_s3_access" {
  name   = "production-bucket-only"
  role   = aws_iam_role.role_c.id
  policy = data.aws_iam_policy_document.role_c_s3_access.json
}
