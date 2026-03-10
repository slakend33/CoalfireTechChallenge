##############################################################################
# MODULE: LOADBALANCER - VARIABLES
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

variable "lb_name" {
  description = "Name of the internal Load Balancer."
  type        = string
  default     = "lb-web-internal"
}

variable "web_subnet_id" {
  description = "Resource ID of the Web subnet for the LB frontend IP."
  type        = string
}

variable "lb_frontend_private_ip" {
  description = <<-EOT
    Static private IP address for the LB frontend configuration.
    Must be an available address within the web subnet CIDR (default: 10.0.4.0/24).
    Avoid .1-.4 (reserved by Azure) and IPs already assigned to VMs.
    Default: 10.0.4.10
  EOT
  type    = string
  default = "10.0.4.10"
}

variable "web_vm_nic_ids" {
  description = "List of NIC resource IDs for the Web VMs to add to the backend pool."
  type        = list(string)
}

variable "web_vm_private_ips" {
  description = "List of private IPs of the Web VMs (informational / for NSG reference)."
  type        = list(string)
}
