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