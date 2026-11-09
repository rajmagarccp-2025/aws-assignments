# Deployment guide

This guide is for an authorized assignment sandbox. The examples include
high-impact IAM permissions and real infrastructure can incur charges. Never
apply a plan you have not reviewed and approved.

## 1. Prepare identities and local inputs

Use approved AWS CLI profiles for the shared-state bootstrap, Account A, and
Account B. Federated credentials/Identity Center are preferred; do not put
access keys in Terraform files. Verify every profile before planning:

```sh
aws sts get-caller-identity --profile assignment
aws sts get-caller-identity --profile account-a
aws sts get-caller-identity --profile account-b
```

For each Terraform root, copy the relevant `terraform.tfvars.example` to an
ignored local `terraform.tfvars`. Replace every account ID and illustrative
resource name. Keep state files, plans, local tfvars, backend configs,
credentials, and PGP private keys out of Git.

Account A console test users require a base64-encoded PGP public key. The
private key must remain under operator control. Passwords are stored in
Terraform state in encrypted form; protect state accordingly.

## 2. Create remote state resources first

Bootstrap uses local state because it creates the S3 bucket that later roots
will use. Set a globally unique state bucket name and confirm the account:

```sh
cd task-2-remote-state/bootstrap
copy terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform fmt -check
terraform validate
terraform plan -out bootstrap.tfplan
terraform show bootstrap.tfplan
# Apply only after approval:
terraform apply bootstrap.tfplan
```

The bucket is private, versioned, encrypted, and TLS-only. The DynamoDB table
uses the `LockID` partition key. Both have deletion safeguards. After bootstrap,
copy `task-2-remote-state/backend.hcl.example` to a private
`task-2-remote-state/bootstrap/backend.hcl`. Set the actual bucket, region, and
table, and set its key to
`devops-assignment/bootstrap/terraform.tfstate`. Migrate the bootstrap root's
local state to S3:

```sh
terraform init -migrate-state -force-copy -backend-config=backend.hcl
```

For later bootstrap runs, initialize it with that same backend config. Give
every workload root/account its own unique state `key`; do not share the
bootstrap key or one workload root's key with another root.

For an existing local-state root, back up its state securely, then migrate
using `terraform init -migrate-state -backend-config=backend.hcl`. For a new
root, use `terraform init -backend-config=backend.hcl`. The backend identity
must be authorized for the state bucket and locking table.

## 3. Provision the EC2 fleet

In `task-1-ec2-provisioning/terraform.tfvars`, supply a valid regional AMI, at
least two private subnets in distinct AZs, reviewed security groups, an
existing least-privilege instance profile, and five existing key pairs. Verify
instance type, EBS type/IOPS, AMI, and AZ availability before planning.

```sh
cd task-1-ec2-provisioning
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out ec2.tfplan
terraform show ec2.tfplan
# Apply only after approval:
terraform apply ec2.tfplan
terraform output
```

The configuration creates five EC2 instances from one map. `production-db`
has `prevent_destroy`; do not remove its guard simply to make a destroy work.
Compute, EBS capacity, and provisioned IOPS incur charges.

## 4. Deploy Account A, then Account B

Create separate private tfvars and unique backend keys for both roots.
Account A must be applied first so roleB exists before Account B creates the
roleC trust.

### Account A

Set actual account IDs and resource names in
`task-3-multi-account-iam/account-a/terraform.tfvars`. The example enables
assignment users and roleA's broad non-IAM policy for the requested sandbox
exercise. It also names the ECR repository, ECS service/task family, task roles,
and artifact bucket used to render the policy attached to `ci`.

The CI policy is created only when assignment IAM users are enabled. The
example also enables assignment-only access keys for all four users so both
groups can use the CLI; those secrets are stored in Terraform state. Verify
that `engine` and `ci` are group1 members, `alice` and `bob` are group2
members, group1 has no console profiles, and group2 receives PGP-encrypted
initial passwords. Retrieve the sensitive `assignment_user_access_keys`
output only when needed in the sandbox, and never paste it into logs or
commit it.

```sh
cd task-3-multi-account-iam/account-a
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out account-a.tfplan
terraform show account-a.tfplan
# Apply only after approval:
terraform apply account-a.tfplan
```

### Account B

Set the actual Account A/B IDs and a globally unique bucket name in
`task-3-multi-account-iam/account-b/terraform.tfvars`. The example enables the
assignment's full `s3:*` action set, but the policy is scoped to the designated
bucket and its objects. Use this only in the assignment sandbox.

```sh
cd task-3-multi-account-iam/account-b
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out account-b.tfplan
terraform show account-b.tfplan
# Apply only after approval:
terraform apply account-b.tfplan
```

Review the exact roleC trust principal and policy resources in the plan. RoleC
must trust the roleB ARN, not Account A root or an IAM user. Confirm the
Account A roleB identity policy permits assumption of only roleC.

## 5. Validate the CI policy

The custom policy template is rendered and attached to `ci` by the Account A
root. Review its rendered JSON in the Account A plan and verify the ECR,
ECS, `iam:PassRole`, and S3 resources match the intended workflow. For an
independent IAM semantic check, copy the rendered policy document from the
plan into a protected temporary JSON file and run:

```sh
python -m json.tool rendered-ci-policy.json
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://rendered-ci-policy.json
```

Do not grant CI access keys for a production pipeline; use OIDC and short-lived
role sessions instead.

## 6. Check and test Task 5

`task-5-iam-debugging/broken.tf` and `fixed.tf` are alternatives and should
not be applied together. The broken file demonstrates a user ARN where the
roleB role ARN is required, plus `s3:*` on `*`. The fixed file trusts only
roleB and limits S3 actions to the bucket and object ARNs.

## 7. GitHub Actions deployment

The manually triggered workflow at
`.github/workflows/terraform-deploy.yml` runs static checks, verifies the
remote-state bucket and lock table, plans and applies Task 1, Account A, and
Account B in dependency order, and skips Task 5 because its broken and fixed
examples are not deployable together. The bootstrap root uses local state
only for its first plan/apply, then migrates that state to the new S3 backend.
Later runs plan and apply the bootstrap root using its remote state.

Before using the workflow:

1. Configure GitHub Actions OIDC in AWS and create four narrowly scoped roles.
   Add these repository variables: `AWS_REGION`, `TF_STATE_BUCKET`,
   `TF_LOCK_TABLE`, `AWS_BOOTSTRAP_ROLE_ARN`, `AWS_TASK1_ROLE_ARN`,
   `AWS_ACCOUNT_A_ROLE_ARN`, and `AWS_ACCOUNT_B_ROLE_ARN`. Each workload role
   must be able to access its own AWS resources and the shared S3/DynamoDB
   Terraform backend. The bootstrap role also needs permission to check,
   create, and manage the state bucket and lock table.
2. Add repository secrets `BOOTSTRAP_TFVARS`, `EC2_TFVARS`,
   `ACCOUNT_A_TFVARS`, and `ACCOUNT_B_TFVARS`. Each secret is the complete
   contents of that root's `terraform.tfvars.example` after replacing all
   placeholders with real values. Set `aws_profile = null` in each file so
   the AWS provider uses the short-lived OIDC credentials. The bootstrap
   `aws_region`, `state_bucket_name`, and `lock_table_name` must match the
   corresponding repository variables; all workload regions must match
   `AWS_REGION`. Ensure each AWS account ID matches the account targeted by
   that root's role. Keep PGP public material and all account-specific inputs
   in the appropriate protected secret/configuration.
3. Create a GitHub Environment named `terraform-apply` and configure required
   reviewers. Apply jobs pause at that environment. Approve only after
   inspecting the corresponding plan output in the preceding plan job.
4. Trigger **Actions → Deploy Terraform assignment → Run workflow** on the
   protected branch. The workflow serializes runs, uses a unique S3 state key
   for each root, and retains each saved plan artifact for one day for the
   gated apply job.

The bootstrap check creates the backend only when both the bucket and lock
table are absent. If only one exists, or AWS reports an access/configuration
error, the workflow stops rather than attempting an unsafe partial bootstrap.
On the initial run, bootstrap state is migrated into
`devops-assignment/bootstrap/terraform.tfstate`. Existing remote-state
resources with no matching bootstrap state need to be imported/reconciled
before using this workflow.

`terraform plan` refreshes state by default; the workflow explicitly uses
`-refresh=true` and applies that saved plan after approval. It does not run a
separate `terraform refresh`. The plan artifact and Terraform state may
contain sensitive data; restrict repository and Actions access accordingly.
The workflow can incur AWS charges and creates assignment IAM users/access
keys when enabled by the supplied variables. Review the security checklist
and plans before approving.

## Validation levels and limitations

1. **Static checks:** `bash scripts/validate.sh` checks formatting and
   Terraform configuration; `bash scripts/test-iam-policies.sh` checks policy
   documents. No AWS resources are created.
2. **Plan:** Requires valid inputs, backend access, and AWS credentials. A
   successful plan does not prove deployment.
3. **Apply and AWS verification:** Only a reviewed, approved apply followed by
   checks in AWS confirms deployed resources.
4. **Functional tests:** Test assumed roles and expected allowed/denied access
   only with authorized identities in a non-production environment.

No AWS plan, apply, deployment, Access Analyzer check, or functional test has
been performed for this repository.
