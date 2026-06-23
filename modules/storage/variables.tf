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

variable "web_app_principal_id" {
  description = "Principal ID of the Web App's System-Assigned Managed Identity (Part II). Used to grant Blob Data access without storing credentials."
  type        = string
}
