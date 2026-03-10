##############################################################################
# main.tf
# Entry point for the Azure Web Server PoC environment.
#
# Contains:
#   1. Resource group
#   2. All Coalfire module calls (terraform-azurerm-nsg × 4)
#
# Supporting resources (VNet, VMs, storage, load balancer) are defined in
# their dedicated .tf files and depend on the outputs of these modules.
##############################################################################

# ─── Resource Group ──────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Coalfire NSG Module – Web Subnet
# Source: github.com/Coalfire-CF/terraform-azurerm-nsg
#
# Purpose  : Allows inbound HTTP/HTTPS from the internet and load-balancer
#            health probes; allows SSH only from the management subnet.
# Denies   : All other inbound traffic.
# ─────────────────────────────────────────────────────────────────────────────

module "nsg_web" {
  source = "github.com/Coalfire-CF/terraform-azurerm-nsg?ref=main"

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  security_group_name = "${local.name_prefix}-web-nsg"

  # ── Flow log wiring (optional – activated by var.enable_nsg_flow_logs) ────
  storage_account_flowlogs_id       = local.flowlog_storage_id
  network_watcher_name              = var.enable_nsg_flow_logs ? local.network_watcher_name : null
  network_watcher_flow_log_name     = var.enable_nsg_flow_logs ? "${local.name_prefix}-web-nsg-flowlog" : null
  network_watcher_flow_log_location = var.enable_nsg_flow_logs ? var.location : null
  diag_log_analytics_id             = local.flowlog_la_id
  diag_log_analytics_workspace_id   = local.flowlog_la_workspace_id

  global_tags   = var.global_tags
  regional_tags = var.regional_tags

  custom_rules = [
    # ── Rule 100: Azure Load Balancer health probes ────────────────────────
    {
      name                       = "Allow-LB-HealthProbe-Inbound"
      priority                   = "100"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
      description                = "Allow Azure LB health probe traffic"
    },
    # ── Rule 110: Inbound HTTP ─────────────────────────────────────────────
    {
      name                       = "Allow-HTTP-Inbound"
      priority                   = "110"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = local.web_subnet_cidr
      description                = "Allow inbound HTTP from any source"
    },
    # ── Rule 120: Inbound HTTPS ────────────────────────────────────────────
    {
      name                       = "Allow-HTTPS-Inbound"
      priority                   = "120"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = local.web_subnet_cidr
      description                = "Allow inbound HTTPS from any source"
    },
    # ── Rule 200: SSH from management subnet → web VMs ────────────────────
    # REQUIREMENT: "NSG allows SSH from management VM to Web VM"
    {
      name                       = "Allow-SSH-From-Management"
      priority                   = "200"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = local.mgmt_subnet_cidr
      destination_address_prefix = local.web_subnet_cidr
      description                = "Allow SSH from management subnet to web VMs"
    },
    # ── Rule 900: Explicit deny-all inbound ───────────────────────────────
    {
      name                       = "Deny-All-Inbound"
      priority                   = "900"
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Explicit deny-all – defence in depth"
    },
    # ── Rule 100: Outbound HTTP (package updates) ──────────────────────────
    {
      name                       = "Allow-HTTP-HTTPS-Outbound"
      priority                   = "100"
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = local.web_subnet_cidr
      destination_address_prefix = "*"
      description                = "Allow HTTP outbound for package updates"
    },
  ]

  depends_on = [
    azurerm_network_watcher.main,
    azurerm_storage_account.flowlogs,
    azurerm_log_analytics_workspace.nsg_diag,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Coalfire NSG Module – Management Subnet
# Source: github.com/Coalfire-CF/terraform-azurerm-nsg
#
# Purpose  : Jump-host subnet. Allows SSH from the VNet ("this network") and
#            optionally from an approved external CIDR.
# REQUIREMENT: "NSG allows SSH from this network"
# ─────────────────────────────────────────────────────────────────────────────

module "nsg_management" {
  source = "github.com/Coalfire-CF/terraform-azurerm-nsg?ref=main"

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  security_group_name = "${local.name_prefix}-mgmt-nsg"

  storage_account_flowlogs_id       = local.flowlog_storage_id
  network_watcher_name              = var.enable_nsg_flow_logs ? local.network_watcher_name : null
  network_watcher_flow_log_name     = var.enable_nsg_flow_logs ? "${local.name_prefix}-mgmt-nsg-flowlog" : null
  network_watcher_flow_log_location = var.enable_nsg_flow_logs ? var.location : null
  diag_log_analytics_id             = local.flowlog_la_id
  diag_log_analytics_workspace_id   = local.flowlog_la_workspace_id

  global_tags   = var.global_tags
  regional_tags = var.regional_tags

  custom_rules = [
    # ── Rule 100: SSH from "this network" (VNet CIDR = 10.0.0.0/16) ──────
    # REQUIREMENT: "NSG allows SSH from this network"
    {
      name                       = "Allow-SSH-From-VNet"
      priority                   = "100"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = local.vnet_cidr
      destination_address_prefix = local.mgmt_subnet_cidr
      description                = "Allow SSH from anywhere within the VNet (10.0.0.0/16)"
    },
    # ── Rule 110: SSH from approved external CIDR (e.g. corporate VPN) ────
    {
      name                       = "Allow-SSH-From-ApprovedExternal"
      priority                   = "110"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.allowed_ssh_source_cidr
      destination_address_prefix = local.mgmt_subnet_cidr
      description                = "Allow SSH from approved external source CIDR"
    },
    # ── Rule 900: Explicit deny-all inbound ───────────────────────────────
    {
      name                       = "Deny-All-Inbound"
      priority                   = "900"
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Explicit deny-all inbound"
    },
    # ── Rule 100: Outbound SSH to web subnet ──────────────────────────────
    {
      name                       = "Allow-SSH-To-Web"
      priority                   = "100"
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = local.mgmt_subnet_cidr
      destination_address_prefix = local.web_subnet_cidr
      description                = "Allow management VM to SSH to web VMs"
    },
    # ── Rule 110: Outbound HTTPS (Azure API, package updates) ─────────────
    {
      name                       = "Allow-Internet-Outbound"
      priority                   = "110"
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = local.mgmt_subnet_cidr
      destination_address_prefix = "Internet"
      description                = "Allow HTTPS outbound for package updates and Azure API"
    },
  ]

  depends_on = [
    azurerm_network_watcher.main,
    azurerm_storage_account.flowlogs,
    azurerm_log_analytics_workspace.nsg_diag,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Coalfire NSG Module – Application Subnet
# Source: github.com/Coalfire-CF/terraform-azurerm-nsg
#
# Purpose  : Middle-tier application servers. Accepts traffic from the web
#            subnet on application ports; SSH from management only.
# ─────────────────────────────────────────────────────────────────────────────

module "nsg_application" {
  source = "github.com/Coalfire-CF/terraform-azurerm-nsg?ref=main"

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  security_group_name = "${local.name_prefix}-app-nsg"

  storage_account_flowlogs_id       = local.flowlog_storage_id
  network_watcher_name              = var.enable_nsg_flow_logs ? local.network_watcher_name : null
  network_watcher_flow_log_name     = var.enable_nsg_flow_logs ? "${local.name_prefix}-app-nsg-flowlog" : null
  network_watcher_flow_log_location = var.enable_nsg_flow_logs ? var.location : null
  diag_log_analytics_id             = local.flowlog_la_id
  diag_log_analytics_workspace_id   = local.flowlog_la_workspace_id

  global_tags   = var.global_tags
  regional_tags = var.regional_tags

  custom_rules = [
    # ── Rule 100: Allow app-port traffic from web tier ────────────────────
    {
      name                       = "Allow-WebTier-Inbound"
      priority                   = "100"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = local.web_subnet_cidr
      destination_address_prefix = local.app_subnet_cidr
      description                = "Allow traffic from web tier to application tier"
    },
    # ── Rule 110: SSH from management subnet ──────────────────────────────
    {
      name                       = "Allow-SSH-From-Management"
      priority                   = "110"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = local.mgmt_subnet_cidr
      destination_address_prefix = local.app_subnet_cidr
      description                = "Allow SSH from management subnet for admin access"
    },
    # ── Rule 900: Explicit deny-all inbound ───────────────────────────────
    {
      name                       = "Deny-All-Inbound"
      priority                   = "900"
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Explicit deny-all inbound"
    },
  ]

  depends_on = [
    azurerm_network_watcher.main,
    azurerm_storage_account.flowlogs,
    azurerm_log_analytics_workspace.nsg_diag,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Coalfire NSG Module – Backend Subnet
# Source: github.com/Coalfire-CF/terraform-azurerm-nsg
#
# Purpose  : Data tier (databases, caches). Accepts DB traffic from the
#            application subnet only; tightly locked down.
# ─────────────────────────────────────────────────────────────────────────────

module "nsg_backend" {
  source = "github.com/Coalfire-CF/terraform-azurerm-nsg?ref=main"

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  security_group_name = "${local.name_prefix}-be-nsg"

  storage_account_flowlogs_id       = local.flowlog_storage_id
  network_watcher_name              = var.enable_nsg_flow_logs ? local.network_watcher_name : null
  network_watcher_flow_log_name     = var.enable_nsg_flow_logs ? "${local.name_prefix}-be-nsg-flowlog" : null
  network_watcher_flow_log_location = var.enable_nsg_flow_logs ? var.location : null
  diag_log_analytics_id             = local.flowlog_la_id
  diag_log_analytics_workspace_id   = local.flowlog_la_workspace_id

  global_tags   = var.global_tags
  regional_tags = var.regional_tags

  custom_rules = [
    # ── Rule 100: SQL traffic from application tier ────────────────────────
    {
      name                       = "Allow-AppTier-DB-Inbound"
      priority                   = "100"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"   # SQL Server; adjust for your DB engine
      source_address_prefix      = local.app_subnet_cidr
      destination_address_prefix = local.be_subnet_cidr
      description                = "Allow SQL traffic from application tier"
    },
    # ── Rule 110: SSH from management subnet ──────────────────────────────
    {
      name                       = "Allow-SSH-From-Management"
      priority                   = "110"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = local.mgmt_subnet_cidr
      destination_address_prefix = local.be_subnet_cidr
      description                = "Allow SSH from management subnet"
    },
    # ── Rule 900: Explicit deny-all inbound ───────────────────────────────
    {
      name                       = "Deny-All-Inbound"
      priority                   = "900"
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Explicit deny-all inbound"
    },
  ]

  depends_on = [
    azurerm_network_watcher.main,
    azurerm_storage_account.flowlogs,
    azurerm_log_analytics_workspace.nsg_diag,
  ]
}
