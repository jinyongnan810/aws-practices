// Goal: Create a read-only IAM user and attach a policy to it.

// Declares a Terraform resource of type aws_iam_user with the terraform local name read_only_user. 
// This creates an IAM user in AWS.
resource "aws_iam_user" "read_only_user" {
  name = "app-reader"
  tags = {
    Environment = "Production"
  }
}

// Declares a resource that attaches a managed IAM policy to a user. Terraform local name is reader_attach.
resource "aws_iam_user_policy_attachment" "reader_attach" {
  user       = aws_iam_user.read_only_user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

// MARK: New Policy for S3 Uploads

# Define the Policy Document (The "What")
data "aws_iam_policy_document" "s3_upload_doc" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::company-upload-bucket/*"
    ]
  }
}

# Create the IAM Policy Resource
resource "aws_iam_policy" "s3_upload_policy" {
  name        = "S3UploadOnlyPolicy"
  description = "Allows writing objects to the company-upload-bucket"
  policy      = data.aws_iam_policy_document.s3_upload_doc.json
}

# Attach the New Policy to the Existing User (The "Who")
resource "aws_iam_user_policy_attachment" "app_reader_s3_attach" {
  user       = aws_iam_user.read_only_user.name
  policy_arn = aws_iam_policy.s3_upload_policy.arn
}

// MARK: trust relationship and attach policy to role

# Define the Trust Relationship (The "Who is allowed to put this on?")
data "aws_iam_policy_document" "ec2_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"] # The specific API call to assume a role

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"] # We are trusting AWS EC2
    }
  }
}

# Create the IAM Role
resource "aws_iam_role" "app_server_role" {
  name               = "AppServerRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json
}

# Attach existing custom policy to the new Role
resource "aws_iam_role_policy_attachment" "role_s3_attach" {
  role = aws_iam_role.app_server_role.name

  # We can reuse the policy we created in the previous step!
  policy_arn = aws_iam_policy.s3_upload_policy.arn
}