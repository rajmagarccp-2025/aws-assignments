# AWS DevOps Terraform and IAM Assignment

An assignment implementation for EC2 provisioning, remote state and locking,
cross-account IAM, a least-privilege CI policy, and IAM policy debugging.
This is a **learning/demo project**, not a production landing zone. Several
permissions are intentionally broad because the assignment asks for them;
deploy only in authorized sandbox accounts after reviewing the plan.

## Start here

1. Read [the deployment guide](docs/deployment-guide.md) before using AWS.
2. Review [the security checklist](docs/security-checklist.md) and
   [assignment notes](NOTES.md).
3. Copy the relevant `*.tfvars.example` and `backend.hcl.example` files to
   ignored local files; replace every illustrative value.
4. Verify the AWS identity and account for each Terraform root before planning.
5. Run static validation, inspect a saved plan, then apply only with explicit
   authorization.

No AWS credentials are included. No `apply`, `destroy`, live IAM validation,
or AWS deployment has been run for this project.

## Assignment map

| Task | Location | Implementation |
|---|---|---|
| 1. EC2 fleet | [`task-1-ec2-provisioning`](task-1-ec2-provisioning/) and [`modules/ec2-fleet`](modules/ec2-fleet/) | Five map-driven instances, distinct configurations, encrypted volumes, required tags, one `prevent_destroy` instance, and name-to-ID/private-IP outputs. |
| 2. State and locking | [`task-2-remote-state`](task-2-remote-state/) | S3 backend with versioning/encryption and DynamoDB locking; bootstrap has separate local state. |
| 3. Multi-account IAM | [`task-3-multi-account-iam`](task-3-multi-account-iam/) | Account A groups/users/roleA/roleB; Account B bucket/roleC with roleB-only trust. |
| 4. CI permissions | [`task-4-ci-iam-policy`](task-4-ci-iam-policy/) | Custom policy template attached to `ci` when assignment IAM users are enabled. |
| 5. IAM bug fix | [`task-5-iam-debugging`](task-5-iam-debugging/) | Wrong user-vs-role principal and overbroad S3 resource scope, with a corrected example. |

Reusable security-focused modules are in [`modules`](modules/). More explanation
is available in the [architecture](docs/architecture.md),
[cleanup guide](docs/cleanup-guide.md), and
[security checklist](docs/security-checklist.md).

## Prerequisites

- Terraform 1.10 or later, AWS CLI v2, Python 3, and an authorized AWS identity.
- Separate AWS profiles for the shared-state bootstrap, Account A, and Account
  B (or the same approved account if your sandbox is arranged that way).
- Real account IDs, a region-valid AMI, private subnet IDs in distinct AZs,
  reviewed security groups, instance profile, and existing EC2 key pairs.
- A globally unique S3 state bucket name and real CI resource names.
- For Account A console test users, a controlled PGP public key. Keep its
  private key secure.

Use federated credentials/Identity Center rather than embedding access keys.
Do not commit local variable files, backend configuration, state, plans,
credentials, or private keys.

## Static validation

From a Bash-compatible shell at the repository root:

```sh
bash scripts/validate.sh
bash scripts/test-iam-policies.sh
```

These are local checks only. They do not prove AWS resource availability,
successful authorization, or deployment. See the [deployment guide](docs/deployment-guide.md)
for per-task setup and plan/apply order.

## Important safety defaults

The IAM users, assignment-only IAM user keys, roleA's broad non-IAM policy,
and roleC's full S3 policy are guarded by switches. The Account A and Account
B example variable files turn on the required assignment behavior for a
sandbox; review those values carefully and do not use them in production.
Access-key secrets are sensitive outputs and are stored in state. The CI
policy is attached only when `ci` is created.

The example account IDs, AMI, bucket, subnet, security-group, key-pair, and
resource names are illustrative placeholders. The EC2 `production-db` example
is protected against Terraform destruction. Never disable that guard merely
to make a destroy succeed.
