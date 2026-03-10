##############################################################################
# ROOT VARIABLES.TF
##############################################################################

# -- General ------------------------------------------------------------------

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

# -- Network ------------------------------------------------------------------

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

# -- Compute ------------------------------------------------------------------

variable "web_vm_count" {
  description = "Number of Web VMs. Must be >= 2 for Availability Set fault isolation."
  type        = number
  default     = 2
}

variable "web_vm_name_prefix" {
  description = "Prefix for Web VM names (e.g. vm-web produces vm-web-01, vm-web-02)."
  type        = string
  default     = "vm-web"
}

variable "mgmt_vm_name" {
  description = "Name of the Management VM."
  type        = string
  default     = "vm-mgmt-01"
}

variable "availability_set_name" {
  description = "Name of the Availability Set for the Web VMs."
  type        = string
  default     = "avset-web"
}

variable "vm_size" {
  description = "Azure VM SKU applied to all VMs."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local administrator username for all VMs."
  type        = string
  default     = "azureuser"
}


# -- OS Image -----------------------------------------------------------------
# Defaults to Ubuntu Server 22.04 LTS Gen2.

variable "vm_image_publisher" {
  description = "Marketplace image publisher."
  type        = string
  default     = "Canonical"
}

variable "vm_image_offer" {
  description = "Marketplace image offer."
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "vm_image_sku" {
  description = "Marketplace image SKU. 22_04-lts-gen2 = Ubuntu 22.04 LTS Gen2."
  type        = string
  default     = "22_04-lts-gen2"
}

variable "vm_image_version" {
  description = "Marketplace image version. Use 'latest' for the newest patch release."
  type        = string
  default     = "latest"
}

# -- Load Balancer ------------------------------------------------------------

variable "lb_name" {
  description = "Name of the internal Load Balancer."
  type        = string
  default     = "lb-web-internal"
}

variable "lb_frontend_private_ip" {
  description = <<-EOT
    Static private IP for the internal Load Balancer frontend.
    Must be within the web subnet CIDR (10.0.4.0/24) and not conflict with
    VM NIC addresses or Azure-reserved addresses (.1 through .4).
  EOT
  type    = string
  default = "10.0.4.10"
}

# -- Storage ------------------------------------------------------------------

variable "storage_account_name" {
  description = "Globally unique Storage Account name (3-24 chars, lowercase alphanumeric)."
  type        = string
  default     = "cfcinfraprod001"
}

# -- Security -----------------------------------------------------------------

variable "key_vault_name" {
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and hyphens)."
  type        = string
  default     = "cfc-prod-001"
}

variable "kv_ip_rules" {
  description = "Public IPs/CIDRs allowed through the Key Vault firewall."
  type        = list(string)
  default     = []
}
variable "sp_name" {
  description = "Display name for the Azure AD Application and Service Principal."
  type        = string
  default     = "sp-infra-prod"
}

variable "user_principals" {
  description = <<-EOT
    Map of named user principals with their Azure AD object IDs and RBAC roles.
    Roles are automatically scoped:
      Storage Blob Data * / Storage Queue Data * -> Storage Account
      Key Vault *                                -> Key Vault
      Everything else (e.g. Contributor)         -> Resource Group
  EOT
  type = map(object({
    object_id = string
    roles     = list(string)
  }))
  default = {}
}
