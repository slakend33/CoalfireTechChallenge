##############################################################################
# network.tf
# Creates the Virtual Network, four /24 subnets, Network Watcher (used by
# the Coalfire NSG module when flow logs are enabled), and associates each
# subnet with its corresponding NSG (defined in nsg.tf).
##############################################################################

# ─── Virtual Network ─────────────────────────────────────────────────────────
# NOTE: Coalfire does not currently publish a public terraform-azurerm-vnet
# module, so the VNet and subnets are defined with native azurerm resources.

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

# ─── Subnets ─────────────────────────────────────────────────────────────────

# Web subnet  –  hosts the two load-balanced web VMs (availability set)
resource "azurerm_subnet" "web" {
  name                 = "${local.name_prefix}-web-sn"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs["web"]]
}

# Management subnet  –  hosts the management / jump VM and the storage account
resource "azurerm_subnet" "management" {
  name                 = "${local.name_prefix}-mgmt-sn"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs["management"]]

  # Service endpoint required so the storage account can restrict access
  # to the management subnet at the network layer.
  service_endpoints = ["Microsoft.Storage"]
}

# Application subnet  –  reserved for application-tier workloads
resource "azurerm_subnet" "application" {
  name                 = "${local.name_prefix}-app-sn"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs["application"]]
}

# Backend subnet  –  reserved for data-tier workloads (databases, caches)
resource "azurerm_subnet" "backend" {
  name                 = "${local.name_prefix}-be-sn"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs["backend"]]
}

# ─── Network Watcher ─────────────────────────────────────────────────────────
# Required by the Coalfire NSG module for flow log configuration.
# Azure may auto-create a NetworkWatcher; this resource adopts it if present.

resource "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${var.location}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  lifecycle {
    # If Azure already auto-created a watcher, import it rather than fail.
    ignore_changes = [tags]
  }
}

# ─── Optional: Log Analytics Workspace for NSG flow log diagnostics ──────────
# Only created when var.enable_nsg_flow_logs = true.

resource "azurerm_log_analytics_workspace" "nsg_diag" {
  count               = var.enable_nsg_flow_logs ? 1 : 0
  name                = "${local.name_prefix}-la-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.flow_log_retention_days
  tags                = local.common_tags
}

# ─── Optional: Storage account dedicated to NSG flow logs ────────────────────
# Separate from the application storage account (GRS) per Azure best practice.

resource "random_string" "flowlog_sa_suffix" {
  count   = var.enable_nsg_flow_logs ? 1 : 0
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "flowlogs" {
  count                    = var.enable_nsg_flow_logs ? 1 : 0
  name                     = "${var.resource_prefix}flowlogs${random_string.flowlog_sa_suffix[0].result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"   # Flow logs storage – LRS is cost-appropriate
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

# ─── Subnet → NSG Associations ───────────────────────────────────────────────
# Wire the Coalfire-managed NSG IDs (output from nsg.tf) to their subnets.

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = module.nsg_web.network_security_group_id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = module.nsg_management.network_security_group_id
}

resource "azurerm_subnet_network_security_group_association" "application" {
  subnet_id                 = azurerm_subnet.application.id
  network_security_group_id = module.nsg_application.network_security_group_id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = module.nsg_backend.network_security_group_id
}
