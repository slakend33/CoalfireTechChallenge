##############################################################################
# TERRAFORM.TFVARS - Replace all placeholder values before applying.
##############################################################################

subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
tenant_id           = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
resource_group_name = "rg-infra-prod"
location            = "East US"

tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "Platform Team"
}

# Network
vnet_name          = "vnet-infra-prod"
vnet_address_space = ["10.0.0.0/16"]
subnets = {
  application = "10.0.1.0/24"
  management  = "10.0.2.0/24"
  backend     = "10.0.3.0/24"
  web         = "10.0.4.0/24"
}

# Compute
web_vm_count          = 2
web_vm_name_prefix    = "vm-web"
mgmt_vm_name          = "vm-mgmt-01"
availability_set_name = "avset-web"
vm_size               = "Standard_B2s"
admin_username        = "azureuser"

# OS Image - Ubuntu Server 22.04 LTS Gen2
# Change all four values together to switch to a different image.
vm_image_publisher = "Canonical"
vm_image_offer     = "0001-com-ubuntu-server-jammy"
vm_image_sku       = "22_04-lts-gen2"
vm_image_version   = "latest"

# NOTE: SSH keys are generated automatically by Terraform (tls_private_key).
# No ssh_public_key entry is required. After apply, retrieve private keys from:
#   Key Vault secret: ssh-private-key-web
#   Key Vault secret: ssh-private-key-mgmt

# Load Balancer
lb_name                = "lb-web-internal"
# Static frontend IP - must be within the web subnet (10.0.4.0/24).
# Azure reserves .1-.4 in every subnet; avoid those and any VM NIC addresses.
lb_frontend_private_ip = "10.0.4.10"

# Storage (must be globally unique across all of Azure, 3-24 lowercase alphanumeric)
# If deployment fails with StorageAccountAlreadyTaken, change this to something unique.
storage_account_name = "cfcinfraprod001"

# Security
key_vault_name = "cfc-prod-001"
sp_name        = "sp-infra-prod"
kv_ip_rules = ["xxx.xxx.xxx.xxx"]

