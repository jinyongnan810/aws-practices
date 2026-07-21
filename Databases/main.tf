# ---------------------------------------------------------
# 1. RDS POSTGRESQL (Relational, VPC-bound)
# ---------------------------------------------------------

# Create a DB Subnet Group (Tells RDS which subnets to live in)
resource "aws_db_subnet_group" "db_subnet" {
  name = "main_db_subnet_group"
  # We place the database in our private subnets for security
  subnet_ids = [
    aws_subnet.private_subnet.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "Main DB Subnet Group"
  }
}

# Provision the RDS PostgreSQL Instance
resource "aws_db_instance" "postgres_db" {
  identifier           = "production-postgres"
  engine               = "postgres"
  engine_version       = "18.4"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  username             = "dbadmin"
  password             = "SuperSecretPassword123!" # Note: Use AWS Secrets Manager in real production!
  db_subnet_group_name = aws_db_subnet_group.db_subnet.name
  skip_final_snapshot  = true # Set to false in production to keep a backup when deleting
}

# ---------------------------------------------------------
# 2. DYNAMODB (Serverless, NoSQL, IAM-secured)
# ---------------------------------------------------------

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