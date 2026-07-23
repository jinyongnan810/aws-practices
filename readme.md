# Terraform AWS Practices

A collection of hands-on Terraform practice projects for provisioning AWS infrastructure. Each top-level folder is a self-contained example with its own state, exploring a different AWS service or pattern.

## Repository contents

| Folder | Description |
| --- | --- |
| `Databases/` | RDS PostgreSQL instance and a DynamoDB table, backed by a dedicated VPC with public/private subnets. |
| `ECS/` | Fargate service behind an Application Load Balancer, with security groups, listener rules, WAFv2 web ACL, CloudWatch alarms (billing, ECS CPU, ALB 5xx) and SNS/Slack notifications. |
| `IAM/new-user/` | IAM users, roles, custom policies and policy attachments (read-only user, S3 upload policy, app server role). |
| `Lambda/` | Python Lambda functions with DynamoDB access, an EventBridge scheduled trigger, and a CloudWatch Logs subscription filter that ships logs to a second log-processor Lambda and S3. |
| `Networking/vpc_and_subnets/` | Core VPC networking: public/private subnets, Internet Gateway, NAT Gateway, plus an EC2 instance with EBS volume, S3 backup bucket and instance profile. |
| `Organizations/` | AWS Organizations setup with an organizational unit and a Service Control Policy (deny S3 bucket delete) attached to it. |

## Tooling

- **[mise](https://mise.jdx.dev/)** (`mise.toml`) manages the `terraform` and `lefthook` versions and defines a `fmt` task that runs `terraform fmt -recursive`.
- **[lefthook](https://github.com/evilmartians/lefthook)** (`lefthook.yml`) runs `mise run fmt` as a pre-commit hook to keep configuration formatted.

## Use common plugin
Following this to avoid duplicated terraform-provider-aws_v6.54.0_x5 in each folder.
```bash
# common cache folder
mkdir -p ~/.terraform.d/plugin-cache

vi ~/.terraformrc
# Add the following to ~/.terraformrc
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
```

## Commands often used
- `terraform init` - Initialize the Terraform working directory.
- `terraform plan` - Generate and show an execution plan.
- `terraform apply` - Build or change infrastructure.
- `terraform destroy` - Destroy Terraform-managed infrastructure.
- `terraform fmt` - Format Terraform configuration files to a canonical format.