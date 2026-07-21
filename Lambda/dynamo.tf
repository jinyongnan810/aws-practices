# Provision a serverless DynamoDB table for user sessions
resource "aws_dynamodb_table" "user_sessions" {
  name         = "UserSessions"
  billing_mode = "PAY_PER_REQUEST" # Serverless auto-scaling billing
  hash_key     = "SessionId"       # The primary key

  attribute {
    name = "SessionId"
    type = "S" # "S" stands for String
  }

  tags = {
    Environment = "Production"
  }
}