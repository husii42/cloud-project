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

variable "tenant_id" {
  type = string
}

variable "object_id" {
  description = "Object ID of the current user / service principal"
  type        = string
}

variable "storage_connection_string" {
  description = "Storage Account connection string to store as a Key Vault secret"
  type        = string
  sensitive   = true
}

variable "tags" {
  type = map(string)
}

variable "web_app_principal_id" {
  description = "Principal ID of the Web App's System-Assigned Managed Identity (Part II). Used to grant read-only secret access without storing credentials."
  type        = string
}
