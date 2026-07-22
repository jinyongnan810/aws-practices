# Deploy a Lambda function that can read/write to a DynamoDB table
# 1. Zip the local Python code (Terraform handles this automatically!)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "index.py"            # The local file you wrote your code in
  output_path = "lambda_function.zip" # The output zip file Terraform creates
}

# 2. Create the Trust Relationship (Who can assume this role?)
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"] # We trust the Lambda service
    }
  }
}

# 3. Create the Execution Role
resource "aws_iam_role" "lambda_exec_role" {
  name               = "LambdaBasicExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# 4. Attach the AWS-managed policy for basic execution (Allows CloudWatch logging)
resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 5. Grant read/write access to the DynamoDB table
data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.user_sessions.arn,
      "${aws_dynamodb_table.user_sessions.arn}/index/*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "LambdaDynamoDBReadWrite"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

# 6. Deploy the Lambda Function
resource "aws_lambda_function" "hello_world_function" {
  function_name = "HelloWorldAPI"
  filename      = data.archive_file.lambda_zip.output_path
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler" # Tells AWS: Look in index.py for a function named handler
  runtime       = "python3.12"

  memory_size = 256 # MB
  timeout     = 60  # seconds

  # Publish a new immutable version each time the code changes
  publish = true

  # This hash tells Terraform to update the function ONLY if your Python code actually changes!
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.user_sessions.name
    }
  }
}

# 7. Alias pointing at the latest published version
resource "aws_lambda_alias" "current" {
  name             = "current"
  function_name    = aws_lambda_function.hello_world_function.function_name
  function_version = aws_lambda_function.hello_world_function.version
}