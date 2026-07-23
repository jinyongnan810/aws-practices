# Caution: Apply this will cause a free account to become a paid account.

# 1. Initialize AWS Organizations (Run from Management Account)
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com"
  ]
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"] # Enables SCP policy type on the root
  feature_set          = "ALL"                      # Enables SCP guardrails across all accounts
}

# 2. Create an Organizational Unit (OU) for Production workloads
resource "aws_organizations_organizational_unit" "prod_ou" {
  name      = "Production"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# 3. Create a Service Control Policy (SCP) to act as a security guardrail
resource "aws_organizations_policy" "deny_s3_bucket_delete" {
  name        = "DenyS3BucketDeletion"
  description = "Prevents any identity in member accounts from deleting S3 buckets"
  type        = "SERVICE_CONTROL_POLICY"

  # Ensure the organization exists (with SCP feature set) before creating the policy
  depends_on = [aws_organizations_organization.org]

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PreventBucketDelete"
        Effect   = "Deny"
        Action   = ["s3:DeleteBucket"]
        Resource = "*"
      }
    ]
  })
}

# 4. Attach the SCP to the Production OU
resource "aws_organizations_policy_attachment" "prod_ou_scp_attach" {
  policy_id = aws_organizations_policy.deny_s3_bucket_delete.id
  target_id = aws_organizations_organizational_unit.prod_ou.id
}