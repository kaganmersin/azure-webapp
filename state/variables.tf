variable "subscription_id" {
  type    = string
  default = "31b0b43d-0900-45b7-86a4-4cdd3cfd2550"
}

variable "tenant_id" {
  type        = string
  default     = "99a06e93-818c-4ac3-8855-b54dd8ba8782"
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

variable "prefix" {
  type        = string
  default     = "tm"
}