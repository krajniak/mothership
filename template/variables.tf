variable "resource_group_name" {
  description = "Name of the resource group (optional, will use workspace-based naming if empty)"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "westeurope"
}