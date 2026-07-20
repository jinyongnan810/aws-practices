# Create an EC2 instance in the private subnet and attach an EBS volume for data storage. 
# Also, set up an S3 bucket for backups with lifecycle rules.
# 1. Look up the latest Amazon Linux 2023 AMI (Operating System Image)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Deploy the EC2 Instance into the Private Subnet
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private_subnet.id # Placing it securely in our private network

  iam_instance_profile = aws_iam_instance_profile.app_server_profile.name

  tags = {
    Name = "Production-App-Server"
  }
}

# 3. Create a secondary EBS Volume for Data Storage
resource "aws_ebs_volume" "data_drive" {
  # The volume MUST be in the same Availability Zone as the EC2 instance
  availability_zone = aws_instance.app_server.availability_zone
  size              = 20    # 20 GB
  type              = "gp3" # General Purpose SSD

  tags = {
    Name = "App-Data-Drive"
  }
}

# 4. Attach the EBS Volume to the EC2 Instance
# use these commands to mount the EBS volume on the EC2 instance:
# # check current disks
# lsblk
# # format the new disk
# sudo mkfs -t xfs /dev/nvme1n1
# # mount the new disk to /data
# sudo mkdir /data
# sudo mount /dev/nvme1n1 /data
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.data_drive.id
  instance_id = aws_instance.app_server.id
}

# 5. Create an S3 Bucket for Long-term Backups
resource "aws_s3_bucket" "app_backups" {
  bucket = "company-unique-backup-bucket-2026" # This must be globally unique!
}

# 6. Add a Lifecycle Rule to save money on storage
resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.app_backups.id

  rule {
    id     = "archive_old_backups"
    status = "Enabled"

    # Automatically move files to cheap Glacier storage after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Automatically delete files after 365 days
    expiration {
      days = 365
    }
  }
}

# Create iam role for ec2
# 1. Define the Trust Relationship (Who can assume this role?)
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. Create the IAM Role
resource "aws_iam_role" "app_server_role" {
  name               = "AppServerRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# 3. Attach the AWS-Managed SSM Policy (Allows Session Manager connection)
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.app_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. Attach S3 Full Access (Solves the previous backup script challenge!)
resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.app_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Note: In production, use a custom least-privilege policy instead of FullAccess!
}

# 5. Create the Instance Profile (The glue between the Role and EC2)
resource "aws_iam_instance_profile" "app_server_profile" {
  name = "AppServerProfile"
  role = aws_iam_role.app_server_role.name
}
