variable "subscription_id" {
  type    = string
  default = "31b0b43d-0900-45b7-86a4-4cdd3cfd2550"
}

variable "tenant_id" {
  type    = string
  default = "99a06e93-818c-4ac3-8855-b54dd8ba8782"
}

variable "application_name" {
  type    = string
  default = "tm"
}

variable "environment" {
  type    = string
  default = "poc"
}

variable "location" {
  description = "Where to locate the AppI ressources"
  type        = string
  default     = "westeurope"
}

variable "location_short" {
  type        = string
  description = "Azure short location - used to build names like storage account name"
  default     = "westeu"
}

variable "sp_os_type" {
  type    = string
  default = "Linux"
}

variable "sp_sku_name" {
  type    = string
  default = "P2v3"
}
