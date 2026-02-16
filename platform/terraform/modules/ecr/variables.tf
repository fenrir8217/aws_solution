variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["svc-a", "svc-b", "svc-c", "svc-d"]
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repositories"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to retain"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
