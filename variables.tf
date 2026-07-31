variable "owner" {
  description = "Learner identifier (firstname-lastname, lowercase, hyphens). Ex: john-doe"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.owner))
    error_message = "owner must be lowercase, letters, digits and hyphens only."
  }
}

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
