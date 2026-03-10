##############################################################################
# MODULE: SECURITY – VARIABLES
##############################################################################

variable "resource_group_name" {
  description = "Name of the Resource Group where the Key Vault will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "subscription_id" {
  description = "Azure Subscription ID (used to construct resource scope paths)."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID for the Key Vault."
  type        = string
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name (3-24 chars, alphanumeric and hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumerics and hyphens."
  }
}

variable "storage_account_id" {
  description = "Resource ID of the Storage Account (for scoped role assignments)."
  type        = string
}

variable "user_principals" {
  description = <<-EOT
    Map of named user principals with their Azure AD object IDs and desired RBAC roles.
    Roles are automatically scoped to the correct Azure resource based on role name:
      - Storage roles  → Storage Account scope
      - Key Vault roles → Key Vault scope
      - All others     → Resource Group scope
    Example:
      {
        "alice" = { object_id = "aaa-bbb-...", roles = ["Contributor"] }
        "bob"   = { object_id = "ccc-ddd-...", roles = ["Storage Blob Data Reader", "Key Vault Secrets User"] }
      }
  EOT
  type = map(object({
    object_id = string
    roles     = list(string)
  }))
  default = {}
}
