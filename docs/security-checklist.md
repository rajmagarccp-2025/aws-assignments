# Security checklist

- [ ] Replace all account IDs, AMI, subnet, key, security group, and bucket
      placeholders with reviewed real values.
- [ ] Authenticate with AWS CLI named profiles/Identity Center; verify the
      target account before every plan.
- [ ] Protect state, plan files, bootstrap credentials, and the PGP private key.
- [ ] Use unique remote state keys per Terraform root and account.
- [ ] Keep assignment-only IAM access-key creation disabled outside a
      disposable sandbox; protect the sensitive output and Terraform state.
- [ ] Prefer federation and short-lived sessions for production access.
- [ ] Review roleA's intentionally broad `NotAction` demonstration before any
      deployment; do not use it as a production admin role.
- [ ] Verify roleC's trust is the exact roleB ARN and its S3 resources are only
      the intended bucket/object ARNs.
- [ ] Set the CI resource names in Account A's local tfvars, inspect the
      rendered inline policy on `ci`, and run IAM Access Analyzer against it.
- [ ] Confirm ECS/ECR resource ARNs and the `iam:PassRole` condition against
      the intended workflow.
- [ ] Confirm EC2 type/EBS/AMI/AZ availability and estimate compute/storage
      costs before approving a plan.
- [ ] Review a saved plan for creates, replacements, and deletes before apply.
- [ ] Preserve the protected EC2 instance; never remove its lifecycle guard
      just to make a destroy succeed.
- [ ] Apply explicit retention/backup controls before deleting production data.
- [ ] Run functional tests only with authorized identities in non-production.
