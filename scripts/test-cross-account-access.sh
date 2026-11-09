#!/usr/bin/env bash
set -u

if [ "$#" -ne 5 ]; then
  printf 'Usage: %s <role-c-profile> <unrelated-account-a-profile> <role-c-arn> <bucket-name> <account-a-id>\n' "$0" >&2
  exit 2
fi

role_c_profile="$1"
unrelated_profile="$2"
role_c_arn="$3"
bucket_name="$4"
account_a_id="$5"
failures=0

if ! command -v aws >/dev/null 2>&1; then
  printf 'FAIL: AWS CLI is required\n'
  exit 1
fi

if aws sts get-caller-identity --profile "$role_c_profile" >/dev/null; then
  printf 'PASS: roleC profile can obtain caller identity\n'
else
  printf 'FAIL: roleC profile could not obtain caller identity\n'
  exit 1
fi

if aws s3api list-objects-v2 --bucket "$bucket_name" --max-keys 1 \
  --profile "$role_c_profile" >/dev/null; then
  printf 'PASS: roleC can list the designated bucket\n'
else
  printf 'FAIL: roleC cannot list the designated bucket\n'
  failures=$((failures + 1))
fi

unrelated_identity="$(aws sts get-caller-identity --profile "$unrelated_profile" --output json 2>/dev/null)"
if [ "$?" -eq 0 ]; then
  unrelated_account="$(printf '%s' "$unrelated_identity" | python -c 'import json,sys; print(json.load(sys.stdin)["Account"])')"
  unrelated_arn="$(printf '%s' "$unrelated_identity" | python -c 'import json,sys; print(json.load(sys.stdin)["Arn"])')"
  if [ "$unrelated_account" != "$account_a_id" ]; then
    printf 'FAIL: unrelated identity is not in the supplied Account A\n'
    exit 1
  fi
  case "$unrelated_arn" in
    *:assumed-role/roleB/*|*:role/roleB)
      printf 'FAIL: negative-test identity is roleB, which is an authorized principal\n'
      exit 1
      ;;
  esac
  printf 'PASS: unrelated principal profile is valid\n'
else
  printf 'FAIL: unrelated principal profile is not authenticated; negative test is inconclusive\n'
  exit 1
fi

error_output="$(aws sts assume-role \
  --profile "$unrelated_profile" \
  --role-arn "$role_c_arn" \
  --role-session-name cross-account-denial-test 2>&1)"
status=$?
if [ "$status" -eq 0 ]; then
  printf 'FAIL: unrelated principal unexpectedly assumed roleC\n'
  failures=$((failures + 1))
elif printf '%s' "$error_output" | grep -Eq 'AccessDenied|AccessDeniedException'; then
  printf 'PASS: unrelated principal was denied roleC assumption\n'
else
  printf 'FAIL: roleC negative test failed for a reason other than AccessDenied\n'
  printf '%s\n' "$error_output" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  printf 'Cross-account checks failed: %s check(s) failed.\n' "$failures"
  exit 1
fi

printf 'Cross-account functional checks passed for the supplied identities.\n'
