##############################################################################
# MODULE: COMPUTE – VARIABLES
##############################################################################

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "web_subnet_id" {
  description = "Resource ID of the Web subnet."
  type        = string
}

variable "management_subnet_id" {
  description = "Resource ID of the Management subnet."
  type        = string
}

variable "web_vm_count" {
  description = "Number of Web VMs to provision."
  type        = number
  default     = 2
}

variable "web_vm_name_prefix" {
  description = "Name prefix for Web VMs (e.g., vm-web → vm-web-01, vm-web-02)."
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
  description = "Azure VM SKU size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for all VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM authentication."
  type        = string
  sensitive   = true
}
