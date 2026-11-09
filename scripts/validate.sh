#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

report() {
  if [ "$1" -eq 0 ]; then
    printf 'PASS: %s\n' "$2"
  else
    printf 'FAIL: %s\n' "$2"
    failures=$((failures + 1))
  fi
}

if ! command -v terraform >/dev/null 2>&1; then
  printf 'FAIL: terraform executable not found\n'
  exit 1
fi

terraform -chdir="$ROOT" fmt -check -recursive
report "$?" "terraform fmt -check -recursive"

configs=(
  "task-1-ec2-provisioning"
  "task-2-remote-state"
  "task-2-remote-state/bootstrap"
  "task-3-multi-account-iam/account-a"
  "task-3-multi-account-iam/account-b"
  "task-5-iam-debugging"
)

for config in "${configs[@]}"; do
  path="$ROOT/$config"
  if terraform -chdir="$path" init -backend=false -input=false -no-color; then
    report 0 "$config terraform init -backend=false"
  else
    report 1 "$config terraform init -backend=false"
    continue
  fi

  if terraform -chdir="$path" validate -no-color; then
    report 0 "$config terraform validate"
  else
    report 1 "$config terraform validate"
  fi
done

if [ "$failures" -gt 0 ]; then
  printf 'Validation failed: %s check(s) failed.\n' "$failures"
  exit 1
fi

printf 'All Terraform static checks passed. This does not validate an AWS plan or deployment.\n'
