# OCP virtual machines

Terraform for the OpenShift bastion and PXE guests. The full install sequence is in the [repository README](../README.md).

```bash
cp terraform.tfvars.example terraform.tfvars
# set cipassword, ssh_key, pm_api_url, and pm_api_token_secret from ../env.local

terraform init
terraform plan
terraform apply
```

Proxmox API credentials, the cloud-init password, and the firewall login are in `../env.local`. Do not paste them into this file. `terraform.tfvars` is gitignored.
