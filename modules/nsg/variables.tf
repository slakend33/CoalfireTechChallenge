##############################################################################
# MODULE: NSG – VARIABLES
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

variable "management_vm_private_ip" {
  description = "Private IP of the Management VM – used as SSH source in NSG rules."
  type        = string
}

variable "loadbalancer_frontend_ip" {
  description = "Frontend private IP of the internal Load Balancer – permitted as web traffic source."
  type        = string
}

variable "web_subnet_id" {
  description = "Resource ID of the Web subnet to associate with the Web NSG."
  type        = string
}

variable "management_subnet_id" {
  description = "Resource ID of the Management subnet to associate with the Management NSG."
  type        = string
}
