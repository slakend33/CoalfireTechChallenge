##############################################################################
# MODULE: NETWORK – VARIABLES
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

variable "vnet_name" {
  type = string
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnet name to CIDR prefix."
  type        = map(string)
}
