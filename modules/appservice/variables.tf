variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "key_vault_uri" {
  description = "URI of the Key Vault, exposed to the app as an environment variable"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Storage Account, exposed to the app as an environment variable"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the Blob Container used for image uploads"
  type        = string
  default     = "images"
}
