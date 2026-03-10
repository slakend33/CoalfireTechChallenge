##############################################################################
# TERRAFORM.TFVARS  –  Replace all placeholder values before applying.
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
ssh_public_key        = "ssh-rsa AAAA...your-public-key-here..."

# Load Balancer
lb_name = "lb-web-internal"

# Storage  (must be globally unique, 3-24 lowercase alphanumeric)
storage_account_name = "stinfraprod001"

# Security
key_vault_name = "kv-infra-prod-001"

user_principals = {
  "infra-admin" = {
    object_id = "00000000-0000-0000-0000-000000000001"
    roles     = ["Contributor"]
  }
  "storage-reader" = {
    object_id = "00000000-0000-0000-0000-000000000002"
    roles     = ["Storage Blob Data Reader"]
  }
  "keyvault-officer" = {
    object_id = "00000000-0000-0000-0000-000000000003"
    roles     = ["Key Vault Secrets Officer"]
  }
}
