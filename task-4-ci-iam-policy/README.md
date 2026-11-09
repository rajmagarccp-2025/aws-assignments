# Task 4 — CI deployment policy

## What this policy does

[`ci-policy.json`](./ci-policy.json) is a Terraform template used by
`task-3-multi-account-iam/account-a`. When
`enable_assignment_iam_users = true`, Terraform renders it and attaches it as
an inline policy to the `ci` IAM user. It allows:

1. ECR authentication and image pushes to one repository.
2. Registration/inspection of one ECS task-definition family and updates to
   one ECS service.
3. Passing only the named ECS task and execution roles to
   `ecs-tasks.amazonaws.com`.
4. Listing and downloading objects from one build-artifacts bucket.

The Account A input variables set these resource names. Replace the illustrative
values in the ignored local `terraform.tfvars` with resources that exist in the
target account before planning. The policy template is not an executable
standalone policy until Terraform renders its `${...}` placeholders.

## Why some actions are excluded

`ecr:GetAuthorizationToken` uses `"Resource": "*"` because ECR requires that
scope. The image push actions are repository-scoped. ECS permissions are
restricted to one task family and service. `iam:PassRole` names only the two
task roles and requires the `ecs-tasks.amazonaws.com` service condition.

The policy does not grant ECR repository administration, ECS service
creation/deletion, task execution, arbitrary IAM changes, wildcard
`iam:PassRole`, or S3 writes/deletes. The artifact bucket grants only
`s3:ListBucket` and `s3:GetObject`.

## Validation

Review the rendered CI policy in the Account A Terraform plan before applying.
For an independent IAM semantic check, copy the rendered policy JSON from the
Account A plan into a protected temporary file and validate it:

```sh
python -m json.tool rendered-ci-policy.json
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://rendered-ci-policy.json
```

Parsing JSON alone does not validate IAM semantics. Prefer GitHub Actions OIDC
and a short-lived IAM role for production CI rather than long-lived IAM user
credentials.
