##############################################################################
# storage.tf
# Creates the application storage account with:
#   • GRS replication (Geo-Redundant Storage)
#   • Network ACL that restricts access to the management subnet only
#     (uses the Microsoft.Storage service endpoint configured on that subnet)
#   • Two blob containers: "terraformstate" and "weblogs"
#
# NOTE: Coalfire does not currently publish a public
# terraform-azurerm-storage-account module, so native azurerm resources
# are used here.
##############################################################################

# ─── Random suffix ────────────────────────────────────────────────────────────
# Azure storage account names must be globally unique, 3-24 lowercase
# alphanumeric characters.  We append a random suffix to guarantee uniqueness.

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ─── Application Storage Account ─────────────────────────────────────────────

resource "azurerm_storage_account" "main" {
  name                = "${var.resource_prefix}${var.environment}sa${random_string.storage_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # ── Redundancy ────────────────────────────────────────────────────────────
  # REQUIREMENT: "GRS Redundant"
  account_tier             = "Standard"
  account_replication_type = "GRS"       # Geo-redundant storage

  # ── Security baseline ─────────────────────────────────────────────────────
  account_kind              = "StorageV2"
  min_tls_version           = "TLS1_2"
  enable_https_traffic_only = true
  allow_nested_items_to_be_public = false  # No anonymous blob access

  # ── Network rules ─────────────────────────────────────────────────────────
  # REQUIREMENT: "Only accessible to the VM in the Management subnet"
  # Default action = Deny blocks all traffic that doesn't match an explicit
  # allow rule.  The management subnet is permitted via its service endpoint
  # (Microsoft.Storage is configured on azurerm_subnet.management).
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]   # Allow Azure-internal traffic (backups, metrics)

    # Allow access from the management subnet's service endpoint.
    # The subnet_id reference enforces that only the management subnet's
    # traffic is permitted; all other VNet subnets are blocked.
    virtual_network_subnet_ids = [
      azurerm_subnet.management.id,
    ]

    # No ip_rules – no public IP access allowed.
    ip_rules = []
  }

  blob_properties {
    # Soft delete protects state files and logs from accidental deletion
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = merge(local.common_tags, { Purpose = "AppStorage" })

  depends_on = [
    # Ensure the service endpoint exists on the subnet before the storage
    # account references it, to avoid a race condition at apply time.
    azurerm_subnet.management,
  ]
}

# ─── Blob Containers ──────────────────────────────────────────────────────────

# REQUIREMENT: Container named "terraformstate"
resource "azurerm_storage_container" "terraformstate" {
  name                  = "terraformstate"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"   # No public read access
}

# REQUIREMENT: Container named "weblogs"
resource "azurerm_storage_container" "weblogs" {
  name                  = "weblogs"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
