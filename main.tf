##############################################################################
# ROOT MAIN.TF
# Orchestrates all child modules for the Azure infrastructure deployment.
#
# Deployment order / timing chain:
#
#   tls_private_key.web + tls_private_key.mgmt  (immediate - no Azure API calls)
#        |
#   module.network + module.storage              (parallel)
#        |
#   time_sleep.after_network (30s)
#        |                       \
#   module.compute            module.security    (parallel; compute needs subnets,
#        |                    (needs storage)     security needs storage + tls keys)
#   time_sleep.after_compute (60s)
#        |
#   module.loadbalancer
#        |
#   time_sleep.after_lb (30s)
#        |
#   module.nsg
##############################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment once the storage account has been provisioned on first apply,
  # then run: terraform init -migrate-state
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "<storage_account_name>"
  #   container_name       = "terraformstate"
  #   key                  = "prod.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}
provider "time" {}
provider "tls" {}

##############################################################################
# Resource Group
##############################################################################

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

##############################################################################
# SSH Key Pairs
# Generated locally by the tls provider - no Azure API call required.
# Public keys are passed to the compute module for VM authentication.
# Private keys are passed to the security module and stored in Key Vault.
##############################################################################

resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "mgmt" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

##############################################################################
# STAGE 1 - Network (parallel with Storage)
##############################################################################

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  vnet_name          = var.vnet_name
  vnet_address_space = var.vnet_address_space
  subnets            = var.subnets

  # Enable the Microsoft.Storage service endpoint on the management subnet so
  # the storage account firewall can restrict access to that subnet only.
  service_endpoint_subnets = {
    management = ["Microsoft.Storage"]
  }
}

# Wait for VNet and subnet IDs to fully propagate in the Azure fabric
# before any resource attempts to attach a NIC to a subnet.
resource "time_sleep" "after_network" {
  create_duration = "30s"
  depends_on      = [module.network]
}

##############################################################################
# STAGE 1 - Storage (parallel with Network)
##############################################################################

module "storage" {
  source = "./modules/storage"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  storage_account_name = var.storage_account_name

  # Management subnet ID sourced from network module output.
  # The storage firewall will only permit traffic originating from this subnet.
  # Depends on after_network to ensure the service endpoint is registered on
  # the subnet before the storage account firewall rule references it.
  management_subnet_id = module.network.subnet_ids["management"]

  depends_on = [time_sleep.after_network]
}

##############################################################################
# STAGE 2 - Compute
# Depends on: time_sleep.after_network (subnet IDs must be propagated)
# SSH public keys sourced from tls_private_key outputs above.
##############################################################################

module "compute" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  # Subnet IDs sourced from network module outputs.
  web_subnet_id        = module.network.subnet_ids["web"]
  management_subnet_id = module.network.subnet_ids["management"]

  web_vm_count          = var.web_vm_count
  web_vm_name_prefix    = var.web_vm_name_prefix
  mgmt_vm_name          = var.mgmt_vm_name
  vm_size               = var.vm_size
  admin_username        = var.admin_username
  availability_set_name = var.availability_set_name

  # OS image - Ubuntu Server 22.04 LTS Gen2
  vm_image_publisher = var.vm_image_publisher
  vm_image_offer     = var.vm_image_offer
  vm_image_sku       = var.vm_image_sku
  vm_image_version   = var.vm_image_version

  # SSH public keys sourced from generated tls_private_key resources.
  # Separate keys are used for web and management VMs.
  ssh_public_key_web  = tls_private_key.web.public_key_openssh
  ssh_public_key_mgmt = tls_private_key.mgmt.public_key_openssh

  depends_on = [time_sleep.after_network]
}

# Wait for VM NIC attachments to fully register in the Azure control plane
# before the Load Balancer module attempts to add NICs to its backend pool.
resource "time_sleep" "after_compute" {
  create_duration = "60s"
  depends_on      = [module.compute]
}

##############################################################################
# STAGE 2 - Security (parallel with Compute)
# Depends on: module.storage (storage_account_id needed for SP role assignment)
# SSH private keys sourced from tls_private_key outputs and stored in Key Vault.
##############################################################################

module "security" {
  source = "./modules/security"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  key_vault_name  = var.key_vault_name
  user_principals = var.user_principals
  sp_name         = var.sp_name
  kv_ip_rules     = var.kv_ip_rules
  # Storage Account ID sourced from storage module output.
  # Used to scope the SP Storage Blob Data Reader role assignment.
  storage_account_id = module.storage.storage_account_id

  # SSH private keys sourced from generated tls_private_key resources.
  # Stored as Key Vault secrets: ssh-private-key-web and ssh-private-key-mgmt.
  ssh_private_key_web  = tls_private_key.web.private_key_pem
  ssh_private_key_mgmt = tls_private_key.mgmt.private_key_pem

  depends_on = [module.storage]
}

##############################################################################
# STAGE 3 - Load Balancer
# Depends on: time_sleep.after_compute (NIC IDs must be registered)
# All IDs sourced from upstream module outputs - no hard-coded values.
##############################################################################

module "loadbalancer" {
  source = "./modules/loadbalancer"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  lb_name = var.lb_name

  # Web subnet ID sourced from network module output.
  web_subnet_id = module.network.subnet_ids["web"]

  # Static frontend IP - must be within the web subnet (10.0.4.0/24) and
  # not overlap with any VM NIC addresses or Azure-reserved addresses (.1-.4).
  lb_frontend_private_ip = var.lb_frontend_private_ip

  # Web VM NIC IDs and private IPs sourced from compute module outputs.
  # Used to register VMs with the LB backend address pool.
  web_vm_nic_ids     = module.compute.web_vm_nic_ids
  web_vm_private_ips = module.compute.web_vm_private_ips

  depends_on = [time_sleep.after_compute]
}

# Wait for the LB frontend private IP to be assigned before the NSG module
# uses it as a permitted traffic source in inbound security rules.
resource "time_sleep" "after_lb" {
  create_duration = "30s"
  depends_on      = [module.loadbalancer]
}

##############################################################################
# STAGE 4 - NSG
# All source IPs sourced from upstream module outputs.
##############################################################################

module "nsg" {
  source = "./modules/nsg"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  # Management VM private IP sourced from compute module output.
  # Used as the permitted SSH source address in the Web NSG.
  management_vm_private_ip = module.compute.management_vm_private_ip

  # LB frontend private IP sourced from loadbalancer module output.
  # Used as the permitted HTTP/HTTPS source address in the Web NSG.
  loadbalancer_frontend_ip = module.loadbalancer.frontend_private_ip

  # Subnet IDs sourced from network module outputs.
  web_subnet_id        = module.network.subnet_ids["web"]
  management_subnet_id = module.network.subnet_ids["management"]

  depends_on = [time_sleep.after_lb]
}
