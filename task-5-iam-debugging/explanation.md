# IAM debugging

The assignment's broken principal is
`arn:aws:iam::000000000000:user/roleB`. That is syntactically a **user** ARN,
not the ARN of the `roleB` IAM role. The correct role principal is
`arn:aws:iam::000000000000:role/roleB`. AWS therefore either rejects the trust
when no IAM user named `roleB` exists, or trusts the wrong identity if that
user does exist. In either case, it does not grant the intended roleB access.
The `broken.tf` and `fixed.tf` examples have distinct input variable names so
the root can validate both configurations. Do not apply the broken example.

The second issue is the permissions policy: `s3:*` on `*` grants roleC every
S3 action on every S3 resource that is otherwise reachable. The fixed policy
retains the assignment's requested full S3 access but limits it to the
designated bucket ARN (bucket-level operations) and its `/*` object ARN
(object-level operations).

The trust document determines who may assume the role. The attached identity
policy determines what the assumed role can do. Cross-account assumption also
requires the caller's identity policy to allow `sts:AssumeRole` on this exact
role.
