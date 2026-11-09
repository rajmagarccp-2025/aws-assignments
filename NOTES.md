# Assignment design notes

## Task 1 — EC2

The five named object entries in `instances` are the single source of instance
configuration. The protected and ordinary instances are selected from that map
into two `for_each` resources because Terraform lifecycle arguments such as
`prevent_destroy` cannot depend on `each.key`. Set
`protected_instance_name` to one of the map keys. Its instance cannot be
destroyed or replaced by Terraform while the lifecycle guard remains enabled;
this is an intentional safeguard, not a way to make the instance immutable.
Back up data and use a reviewed, deliberate procedure before changing the
protected instance.

The example uses five distinct instance types and root volume types, with
`io1` and `io2` IOPS values set explicitly. EC2 type, AMI, EBS type, IOPS,
volume-size, and AZ compatibility are region/AZ-specific and may change. The
provided AMI, subnet, account, key-pair, and security-group values are
placeholders, not validated identifiers. Before planning, confirm each type
supports the selected EBS volume and IOPS in the chosen AZ with AWS's current
regional service documentation and `describe-instance-types` /
`describe-instance-type-offerings`. Use a current AMI in that region and
ensure each named key pair already exists there. `standard` is retained as a
distinct legacy magnetic root-volume example; use it only if available and
appropriate in the chosen region. Prefer gp3 or io2 for real workloads.

The reusable `modules/ec2-fleet` requires at least two private subnet IDs and
checks that they resolve to distinct Availability Zones, then distributes the
instances across them. It also requires explicit security groups and an
existing least-privilege instance profile, disables public-IP association,
requires IMDSv2, disables metadata tags, enables detailed monitoring and EBS
optimization, and encrypts the root volume. Create an instance profile with
only the workload permissions it needs (often Systems Manager access); never
put AWS access keys on an instance. `enable_assignment_ssh_key_pairs` defaults
to false so production instances can use Systems Manager/federated access and
avoid inbound SSH. The assignment example explicitly enables the required
distinct SSH key pairs. The required storage-type examples deliberately
include gp2 and legacy magnetic `standard`; choose gp3 or io2 based on measured
production performance and cost. These standalone EC2 instances do not provide
autoscaling or automatic application failover; `prevent_destroy` is not a
backup or HA strategy.

The `key_name` field is optional when assignment SSH key pairs are disabled.
When they are enabled, each instance must supply a distinct, non-empty key-pair
name.

## Task 2 — State and locking

Local Terraform state is a file in a working directory that records Terraform's
mapping of configuration to real resource IDs and stores attributes returned
by providers. Independent local state files do not coordinate: engineers may
plan against stale snapshots, overwrite each other's changes, or create
duplicate/conflicting resources. S3 gives a team a shared state object;
versioning supports recovery, encryption protects stored data, and the
DynamoDB `LockID` table coordinates mutually exclusive Terraform operations.
The backend example enables both S3-native lockfiles (Terraform 1.10+) and the
assignment's DynamoDB lock table; consult current Terraform guidance before
using legacy DynamoDB locking for a new production environment. A lock is not a
substitute for review or state backups.

State may contain passwords, encrypted/generated credentials, resource
attributes, and infrastructure metadata even when source configuration has no
secrets. Treat it as sensitive: restrict bucket/table access, use short-lived
identities, keep state out of Git, and protect local copies and plans.

Bootstrap the bucket and lock table from `task-2-remote-state/bootstrap` with
local bootstrap state. Do not configure that bootstrap root to use the bucket
it is creating. Then copy `backend.hcl.example` to a private per-environment
`backend.hcl`, substitute the actual bucket, region, table, and a unique key,
and initialize each workload root with `terraform init
-backend-config=backend.hcl`. Use a different key for every root/account. If a
root already has local state, first back up the state file securely and use
`terraform init -migrate-state -backend-config=backend.hcl`; inspect the
migration prompt and resulting state. Never overwrite another root's state
key. AWS's Terraform S3 backend documentation should be checked for current
locking support and deprecation guidance; this assignment explicitly uses its
requested DynamoDB lock table.

The reusable `modules/secure-s3-bucket` standardizes public-access blocking,
bucket-owner-enforced ownership, versioning, encryption (optional customer
KMS key), and a TLS-only bucket policy. The state bucket and lock table have
deletion guards. Removing them requires moving state and making a separate,
reviewed change to those guards after secure backups.

## Task 3 — IAM users, roles, and cross-account access

The configurations create the IAM groups. The four assignment users, group
memberships, and console profiles are gated by `enable_assignment_iam_users`,
which defaults to false. Enable it only in an authorized assignment sandbox.
Production human access should use IAM Identity Center/federation, not these
IAM users. Access-key creation is separately gated by
`enable_assignment_iam_access_keys`, which defaults to false. The example
Account A variable file enables these users and assignment-only keys to
demonstrate CLI access; replace its placeholder values before planning.
Access-key secrets are exposed only through a sensitive Terraform output but
are still stored in Terraform state. Do not enable this option outside a
disposable, isolated sandbox.
Group1 users have no console login profile; group2 users receive generated,
PGP-encrypted initial console passwords and must reset them at first sign-in.
Supply a real, controlled PGP public key through the ignored local tfvars file;
the private key is never part of Terraform or this repository. Encrypted
passwords remain in Terraform state even when PGP-encrypted, so state access
must be strictly restricted.

`enable_assignment_role_a_broad_permissions` defaults to false. With that
default roleA can only assume the specifically scoped roleB; it is not an
administrative role. The Account A example enables the required broad non-IAM
assignment policy for a sandbox; never use it in production. RoleC defaults to
a limited set of bucket/object data operations. The Account B example enables
the requested `s3:*` action set, but scopes it to the one designated bucket.
Use that setting only in an authorized assignment sandbox.

1. **Would I create `engine` and `ci` IAM users and long-lived keys in
   production?** No. IAM users and static keys create a durable credential
   theft/rotation/revocation burden. The example's keys are only for the
   isolated assignment exercise; use federation and short-lived role sessions
   in production.
2. **What instead?** Use IAM Identity Center/federation for human engineers,
   short-lived role sessions for AWS workloads, and GitHub Actions OIDC
   federation to a narrowly scoped deployment role for CI/CD. Issue CLI
   sessions through the federated identity system rather than distributing
   permanent IAM user keys.
3. **Why is Account A root trust different from trusting roleB?** Trusting
   `arn:aws:iam::<A>:root` as a role principal delegates the decision to
   Account A: an identity in that account may assume the role if Account A
   grants it `sts:AssumeRole`. It does not mean only the root user can assume
   it. Trusting `arn:aws:iam::<A>:role/roleB` names that role as the principal,
   narrowing the trust relationship to that identity. RoleC uses the latter.
4. **Trust vs permissions policy?** A role trust (assume-role) policy is the
   resource-based policy that decides which principal may obtain a role
   session. The role's permissions policy decides what an authorized session
   can do after assuming it. Neither grants the other capability.
5. **Why are both cross-account sides needed?** The Account A caller (roleB)
   must have an identity policy allowing `sts:AssumeRole` on the exact Account
   B roleC ARN; Account B roleC must trust roleB. Both authorizations must
   permit the request, in addition to there being no applicable explicit deny.

RoleB's only identity permission is `sts:AssumeRole` on roleC's exact ARN.
RoleC trusts only the canonical roleB ARN. By default, its S3 permissions are
limited to list/location and read/write object operations on the designated
bucket; full `s3:*` is available only through the explicit assignment opt-in.
An external ID is mainly a third-party
confused-deputy control and is not useful for this direct role-to-role trust
arrangement; adding a condition without a caller-controlled external ID would
break the required assumption flow. The dedicated bucket has public access
blocked and bucket-owner-enforced ownership.

When explicitly enabled, roleA demonstrates `NotAction: iam:*` with
`Resource: "*"`. It allows broad actions for every service other than IAM,
including services created in the future; it is not equivalent to a carefully
scoped administrator policy, and it can still enable significant destructive
actions or indirect privilege escalation through non-IAM services. IAM
exclusion does not make the policy safe or least-privilege. The group2 policy
allows Alice and Bob to assume this role, so enabling the broad policy is a
high-impact demonstration and must not be copied into production without a
separately reviewed permission design. The policy's IAM exclusion also omits
`iam:PassRole`, so roleA cannot pass roles through that permission.

The Account A root trust on roleA is accompanied by an explicit identity
permission attached to group2; group membership alone does not grant role
assumption. Group1 has no console profiles. The CI user receives the Task 4
custom inline policy when assignment users are enabled; `engine` receives no
additional permissions because none are specified in the assignment.
Console password creation through Terraform is not the recommended production
identity lifecycle; prefer Identity Center and avoid IAM user passwords as
well as access keys.

## Task 4 — CI policy boundaries

The policy template is rendered and attached as an inline policy to `ci` by
Account A Terraform when assignment users are enabled. Its resource names are
inputs in Account A's local tfvars. The policy permits the five
repository-scoped ECR push actions and
`ecr:GetAuthorizationToken` on `*` because AWS requires that resource scope for
the authorization token. It allows registration/description for a single task
definition family and description/update of one ECS service. Only the exact
task execution and task roles may be passed, and only to
`ecs-tasks.amazonaws.com`.

The artifact bucket grants only `s3:ListBucket` on the bucket ARN and
`s3:GetObject` on its object ARN. Writes, deletes, bucket policy/ACL changes,
and unrelated buckets are intentionally excluded. The deployment does not
grant cluster discovery, service creation/deletion, task execution, arbitrary
IAM changes, or wildcard `PassRole`. If a real pipeline requires an additional
action, validate that workflow and add only the narrow resource/action needed.
Use Access Analyzer to check the substituted policy for AWS action/resource
compatibility before attaching it.

## Task 5 — Debugging

The supplied principal is a user ARN,
`arn:aws:iam::000000000000:user/roleB`, but the intended principal is the
roleB role. The correct ARN is
`arn:aws:iam::000000000000:role/roleB`. If no user named `roleB` exists, AWS
rejects the trust principal; if one does exist, the policy trusts that user
instead of the role. `fixed.tf` uses the canonical role ARN.

The original `Action = "s3:*"` with `Resource = "*"` is excessively broad: it
grants every S3 action on every S3 resource to roleC, subject only to unrelated
boundaries or explicit denies. The corrected policy preserves the exercise's
requested full S3 access but limits resources to the company bucket ARN and
`company-production-data/*`. Bucket-level and object-level ARNs are both
required for full bucket/object operations.

## Validation status

The repository is static assignment work. Terraform formatting, initialization
without a backend, and configuration validation are local checks only. They do
not prove that AWS accepts a plan, that a resource is available in a specific
region, that permissions are sufficient, or that deployment succeeded.
No `terraform plan` against authenticated AWS, `apply`, AWS IAM Access Analyzer,
functional assume-role test, or AWS resource verification has been performed.
See the deployment guide for the distinction between static, plan, deployment,
and functional validation.
