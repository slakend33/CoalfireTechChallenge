##############################################################################
# ROOT MAIN.TF
# Orchestrates all child modules for the Azure infrastructure deployment.
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }

  # Uncomment to use the "terraformstate" blob container for remote state.
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

##############################################################################
# Resource Group
##############################################################################

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

##############################################################################
# Module: Network
# Creates the VNet and four /24 subnets.
##############################################################################

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  vnet_name          = var.vnet_name
  vnet_address_space = var.vnet_address_space

  subnets = var.subnets
}

##############################################################################
# Module: NSG
# Creates the Network Security Group and associates it with subnets.
##############################################################################

module "nsg" {
  source = "./modules/nsg"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  management_vm_private_ip = module.compute.management_vm_private_ip
  loadbalancer_frontend_ip = module.loadbalancer.frontend_private_ip

  web_subnet_id        = module.network.subnet_ids["web"]
  management_subnet_id = module.network.subnet_ids["management"]

  depends_on = [module.network, module.compute, module.loadbalancer]
}

##############################################################################
# Module: Storage
# Creates a GRS storage account with two blob containers.
##############################################################################

module "storage" {
  source = "./modules/storage"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  storage_account_name = var.storage_account_name
}

##############################################################################
# Module: Load Balancer
# Internal load balancer targeting the Web subnet VMs.
##############################################################################

module "loadbalancer" {
  source = "./modules/loadbalancer"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  lb_name           = var.lb_name
  web_subnet_id     = module.network.subnet_ids["web"]
  web_vm_nic_ids    = module.compute.web_vm_nic_ids
  web_vm_private_ips = module.compute.web_vm_private_ips

  depends_on = [module.network, module.compute]
}

##############################################################################
# Module: Compute
# Availability Set + 2 Web VMs + 1 Management VM.
##############################################################################

module "compute" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  web_subnet_id        = module.network.subnet_ids["web"]
  management_subnet_id = module.network.subnet_ids["management"]

  web_vm_count       = var.web_vm_count
  web_vm_name_prefix = var.web_vm_name_prefix
  mgmt_vm_name       = var.mgmt_vm_name
  vm_size            = var.vm_size
  admin_username     = var.admin_username
  ssh_public_key     = var.ssh_public_key

  availability_set_name = var.availability_set_name

  depends_on = [module.network]
}

##############################################################################
# Module: Security
# Azure AD principals, role assignments, and Key Vault (optional secrets).
##############################################################################

module "security" {
  source = "./modules/security"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  subscription_id      = var.subscription_id
  storage_account_id   = module.storage.storage_account_id
  key_vault_name       = var.key_vault_name
  tenant_id            = var.tenant_id
  user_principals      = var.user_principals

  depends_on = [module.storage]
}
