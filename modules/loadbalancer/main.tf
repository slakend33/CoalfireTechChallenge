##############################################################################
# ROOT VARIABLES.TF
##############################################################################

# ── General ──────────────────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure Subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Resource Group."
  type        = string
  default     = "rg-infra-prod"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "East US"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "vnet-infra-prod"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnet names to their CIDR prefixes."
  type        = map(string)
  default = {
    application = "10.0.1.0/24"
    management  = "10.0.2.0/24"
    backend     = "10.0.3.0/24"
    web         = "10.0.4.0/24"
  }
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "web_vm_count" {
  description = "Number of Web VMs (should be 2)."
  type        = number
  default     = 2
}

variable "web_vm_name_prefix" {
  description = "Prefix for Web VM names."
  type        = string
  default     = "vm-web"
}

variable "mgmt_vm_name" {
  description = "Name of the Management VM."
  type        = string
  default     = "vm-mgmt-01"
}

variable "availability_set_name" {
  description = "Name of the Availability Set for Web VMs."
  type        = string
  default     = "avset-web"
}

variable "vm_size" {
  description = "VM SKU size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for all VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key content for VM authentication."
  type        = string
  sensitive   = true
}

# ── Load Balancer ─────────────────────────────────────────────────────────────

variable "lb_name" {
  description = "Name of the internal Load Balancer."
  type        = string
  default     = "lb-web-internal"
}

# ── Storage ───────────────────────────────────────────────────────────────────

variable "storage_account_name" {
  description = "Globally unique Storage Account name (3-24 chars, lowercase alphanumeric)."
  type        = string
  default     = "stinfraprod001"
}

# ── Security ──────────────────────────────────────────────────────────────────

variable "key_vault_name" {
  description = "Name of the Azure Key Vault."
  type        = string
  default     = "kv-infra-prod-001"
}

variable "user_principals" {
  description = "Map of user display names to their Azure AD object IDs and assigned roles."
  type = map(object({
    object_id = string
    roles     = list(string)
  }))
  default = {
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
}
