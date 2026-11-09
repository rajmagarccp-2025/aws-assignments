# Architecture overview

## Terraform roots and dependencies

Each task directory is an independent Terraform root. The reusable modules
live under `modules/`.

```text
Shared/bootstrap account
  task-2-remote-state/bootstrap (local state)
       ├── versioned/encrypted private S3 state bucket
       └── DynamoDB LockID table

Account A
  group1: engine, ci (no console login profiles)
       └── ci has the Task 4 deployment policy when assignment users are enabled
  group2: alice, bob (console profiles are PGP-encrypted)
       └── may assume roleA
             ├── broad non-IAM assignment permissions (sandbox opt-in)
             └── may assume roleB
                   └── may assume only Account B roleC

Account B
  roleC trusts only Account A roleB
       └── access to the named bucket (limited by default;
           assignment example enables full S3 access on that bucket)

Task 1
  five EC2 instances from one map
       └── production-db has lifecycle.prevent_destroy
```

Bootstrap must remain on local state because it creates the remote backend.
Every other Terraform root/account must use a distinct S3 backend key. Apply
Account A before Account B so the roleB principal exists before Account B
creates roleC's trust.

## Policy and lifecycle boundaries

- Task 1 outputs maps of instance names to IDs and private IPs.
- Task 4 restricts CI to one ECR repository, task-definition family, ECS
  service, two passed task roles, and read-only access to one artifact bucket.
- Assignment-only IAM user keys are behind a separate opt-in and stored in
  state; production users and CI should use federation and short-lived role
  sessions.
- The shared S3 module applies public-access blocks, bucket-owner-enforced
  ownership, encryption, versioning, and TLS-only access.

See [NOTES.md](../NOTES.md) for the assignment answers and security tradeoffs.
