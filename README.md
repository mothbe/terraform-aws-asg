# Option 4

# Description

Terraform has been choosen because letsm define infrastructure resources
in human-readable configuration files that you can version, reuse, and share.

This code has been tested by `tfsec`.
Tfsec is a static analysis security scanner for Terraform code.


# Deployment instruction

1. Export environment variables for your AWS account or configure AWS CLI.
```
export AWS_ACCESS_KEY_ID="XYZ"
export AWS_SECRET_ACCESS_KEY="xyz"
export AWS_SESSION_TOKEN="secret"
```

2. Install Terraform v1.2.2 from https://www.terraform.io/downloads

3. Execute following command to create infrastructure:
```
terraform init
terraform plan
terraform apply -auto-approve
```
Terraform  provides Load Balancer url on output after successfull deployment

4. Use following command to destroy infrastructure:
```
terraform destroy -auto-approve
```
