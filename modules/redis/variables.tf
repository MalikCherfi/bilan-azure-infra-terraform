variable "resource_group_name" {
  description = "Name of the Resource Group pre-created by the trainer. Ex: rg-john-doe"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}

variable "keyvault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "keyvault_access_policy" {
  description = "Key Vault access policy"
  type        = string
}

variable "wait_for_access_policy" {
  description = "Wait for access policy"
  type        = bool
  default     = false
}
