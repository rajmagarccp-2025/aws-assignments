#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/task-4-ci-iam-policy/ci-policy.json"
failures=0

if ! python -m json.tool "$POLICY" >/dev/null; then
  printf 'FAIL: CI IAM policy is not valid JSON\n'
  exit 1
fi
printf 'PASS: CI IAM policy parses as JSON\n'

python - "$POLICY" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as policy_file:
    policy = json.load(policy_file)

statements = policy.get("Statement", [])
assert isinstance(statements, list), "Statement must be an array"

actions = {
    action
    for statement in statements
    for action in (
        statement.get("Action", [])
        if isinstance(statement.get("Action", []), list)
        else [statement.get("Action")]
    )
}
required = {
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:CompleteLayerUpload",
    "ecr:InitiateLayerUpload",
    "ecr:PutImage",
    "ecr:UploadLayerPart",
    "ecs:RegisterTaskDefinition",
    "ecs:DescribeServices",
    "ecs:DescribeTaskDefinition",
    "ecs:UpdateService",
    "iam:PassRole",
    "s3:GetObject",
    "s3:ListBucket",
}
missing = required - actions
assert not missing, f"Missing required actions: {sorted(missing)}"
assert "s3:PutObject" not in actions, "Build artifact bucket must be read-only"
assert "s3:DeleteObject" not in actions, "Build artifact bucket must be read-only"
assert "iam:*" not in actions, "Unrestricted IAM actions are prohibited"

for statement in statements:
    action_list = statement.get("Action", [])
    if not isinstance(action_list, list):
        action_list = [action_list]
    resources = statement.get("Resource", [])
    if not isinstance(resources, list):
        resources = [resources]
    if action_list == ["ecr:GetAuthorizationToken"]:
        assert resources == ["*"], "ECR authorization token must use Resource *"
    elif any(action.startswith("ecr:") for action in action_list):
        assert all(":repository/" in resource for resource in resources), (
            "ECR repository actions must be repository-scoped"
        )
    if "iam:PassRole" in action_list:
        assert statement.get("Condition", {}).get("StringEquals", {}).get(
            "iam:PassedToService"
        ) == "ecs-tasks.amazonaws.com", "PassRole must be limited to ECS tasks"
    if any(action.startswith("s3:") for action in action_list):
        assert all("${build_artifacts_bucket}" in resource for resource in resources), (
            "S3 access must be scoped to the build_artifacts_bucket template variable"
        )
        assert all(action in {"s3:GetObject", "s3:ListBucket"} for action in action_list), (
            "Only read-only S3 actions are allowed"
        )

print("PASS: CI policy required actions and resource boundaries are present")
PY
status=$?
if [ "$status" -ne 0 ]; then
  printf 'FAIL: CI IAM policy boundary check\n'
  failures=$((failures + 1))
fi

if grep -q '\${' "$POLICY"; then
  printf 'SKIP: IAM Access Analyzer validation; render the Terraform policy template first\n'
elif command -v aws >/dev/null 2>&1; then
  if aws accessanalyzer validate-policy \
    --policy-type IDENTITY_POLICY \
    --policy-document "file://$POLICY" >/dev/null; then
    printf 'PASS: IAM Access Analyzer policy validation\n'
  else
    printf 'FAIL: IAM Access Analyzer policy validation\n'
    failures=$((failures + 1))
  fi
else
  printf 'SKIP: IAM Access Analyzer CLI validation; AWS CLI not installed\n'
fi

if [ "$failures" -gt 0 ]; then
  printf 'IAM policy checks failed: %s check(s) failed.\n' "$failures"
  exit 1
fi

printf 'Local IAM JSON/boundary checks completed. Semantic AWS validation may still be required.\n'
