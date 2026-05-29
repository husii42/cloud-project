variable "project_name" {
  description = "Short name used as prefix for all resources (lowercase, no spaces)"
  type        = string
  default     = "cloudproject"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "cloud-devops-engineering"
    university  = "Aalen"
    managed_by  = "terraform"
  }
}
