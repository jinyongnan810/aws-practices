# Terraform AWS Practices

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