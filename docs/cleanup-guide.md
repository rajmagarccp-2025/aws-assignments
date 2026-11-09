# Cleanup guide

Cleanup is a destructive AWS operation. Confirm the account, region, state
backend key, and plan with the resource owner before proceeding. Never run
`terraform destroy` against the protected Task 1 instance: its
`prevent_destroy` guard is intentional. Preserve required data from the
production bucket before deleting anything.

Suggested order after explicit approval:

1. Remove Task 1 ordinary instances with a reviewed plan. The protected
   `production-db` instance prevents a destroy while the guard is active;
   preserve it rather than bypassing that protection.
2. Remove Account B roleC policy/role and the designated bucket only after its
   contents and versions have been reviewed and retained/backed up as needed.
   The bucket may require emptying all object versions and delete markers before
   AWS permits deletion; do this only under an approved data-retention plan.
3. Remove Account A roleB/roleA policies and roles, groups, users, the `ci`
   inline policy, and login profiles only after access and password
   dependencies are checked.
4. Keep the remote state bucket and lock table until every workload using them
   has been safely decommissioned and its final state retained. Delete state
   infrastructure last, only if policy permits; bucket versioning means old
   versions must be considered separately.

The S3 bucket module and DynamoDB table have destruction protections enabled.
Do not remove these protections as a routine cleanup shortcut. If decommission
is approved, first migrate or archive state, verify retained backups, then
make a separate reviewed change to the lifecycle/deletion-protection settings
before planning deletion.

Use the matching root and named AWS profile. Run `terraform plan -destroy` (or
normal plan after a reviewed configuration change), inspect the saved plan,
and obtain approval before `terraform destroy`. Do not automate bucket
emptying or bypass `prevent_destroy`. No cleanup commands have been run for
this assignment.
