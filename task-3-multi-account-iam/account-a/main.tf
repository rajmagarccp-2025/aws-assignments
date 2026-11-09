resource "aws_iam_group" "group1" {
  name = "group1"
}

resource "aws_iam_group" "group2" {
  name = "group2"
}

resource "aws_iam_user" "group1" {
  for_each = var.enable_assignment_iam_users ? toset(["engine", "ci"]) : toset([])
  name     = each.key
  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_iam_user" "group2" {
  for_each = var.enable_assignment_iam_users ? toset(["alice", "bob"]) : toset([])
  name     = each.key
  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_iam_group_membership" "group1" {
  count = var.enable_assignment_iam_users ? 1 : 0

  name  = "group1-members"
  users = [for user in aws_iam_user.group1 : user.name]
  group = aws_iam_group.group1.name
}

resource "aws_iam_group_membership" "group2" {
  count = var.enable_assignment_iam_users ? 1 : 0

  name  = "group2-members"
  users = [for user in aws_iam_user.group2 : user.name]
  group = aws_iam_group.group2.name
}

resource "aws_iam_user_login_profile" "group2" {
  for_each                = var.enable_assignment_iam_users ? aws_iam_user.group2 : {}
  user                    = each.value.name
  pgp_key                 = var.console_login_pgp_key
  password_reset_required = true
}

resource "aws_iam_access_key" "assignment_users" {
  for_each = var.enable_assignment_iam_access_keys ? merge(
    aws_iam_user.group1,
    aws_iam_user.group2
  ) : {}

  user = each.value.name
}

resource "aws_iam_user_policy" "ci_deployment" {
  for_each = var.enable_assignment_iam_users ? {
    for username, user in aws_iam_user.group1 : username => user
    if username == "ci"
  } : {}

  name = "ci-deploy-to-assignment-resources"
  user = each.value.name
  policy = templatefile("${path.module}/../../task-4-ci-iam-policy/ci-policy.json", {
    region                   = var.aws_region
    account_id               = var.account_a_id
    ecr_repository           = var.ci_ecr_repository_name
    ecs_cluster              = var.ci_ecs_cluster_name
    ecs_service              = var.ci_ecs_service_name
    ecs_task_family          = var.ci_ecs_task_family
    task_execution_role_name = var.ci_task_execution_role_name
    task_role_name           = var.ci_task_role_name
    build_artifacts_bucket   = var.ci_build_artifacts_bucket
  })
}

data "aws_iam_policy_document" "role_a_trust" {
  statement {
    sid     = "AccountADelegation"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:root"]
    }
  }
}

resource "aws_iam_role" "role_a" {
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.role_a_trust.json
  tags = {
    Name        = "roleA"
    Environment = var.environment
    Owner       = var.owner
  }
}

data "aws_iam_policy_document" "role_a_permissions" {
  statement {
    sid         = "AllowAllServiceActionsExceptIAM"
    effect      = "Allow"
    not_actions = ["iam:*"]
    resources   = ["*"]
  }
}

resource "aws_iam_role_policy" "role_a_permissions" {
  count  = var.enable_assignment_role_a_broad_permissions ? 1 : 0
  name   = "roleA-services-except-iam"
  role   = aws_iam_role.role_a.id
  policy = data.aws_iam_policy_document.role_a_permissions.json
}

data "aws_iam_policy_document" "role_a_assume_role_b" {
  statement {
    sid       = "AssumeRoleB"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.role_b.arn]
  }
}

resource "aws_iam_role_policy" "role_a_assume_role_b" {
  name   = "assume-roleB-only"
  role   = aws_iam_role.role_a.id
  policy = data.aws_iam_policy_document.role_a_assume_role_b.json
}

data "aws_iam_policy_document" "group2_assume_role_a" {
  statement {
    sid       = "AssumeRoleA"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.role_a.arn]
  }
}

resource "aws_iam_group_policy" "group2_assume_role_a" {
  name   = "assume-roleA"
  group  = aws_iam_group.group2.name
  policy = data.aws_iam_policy_document.group2_assume_role_a.json
}

data "aws_iam_policy_document" "role_b_trust" {
  statement {
    sid     = "TrustRoleA"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role_a.arn]
    }
  }
}

resource "aws_iam_role" "role_b" {
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.role_b_trust.json
  tags = {
    Name        = "roleB"
    Environment = var.environment
    Owner       = var.owner
  }
}

data "aws_iam_policy_document" "role_b_permissions" {
  statement {
    sid       = "AssumeOnlyRoleC"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${var.account_b_id}:role/roleC"]
  }
}

resource "aws_iam_role_policy" "role_b_permissions" {
  name   = "assume-account-b-roleC-only"
  role   = aws_iam_role.role_b.id
  policy = data.aws_iam_policy_document.role_b_permissions.json
}
