variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://)"
  type        = string
  default     = ""
}

variable "eks_namespace" {
  description = "Kubernetes namespace for service accounts"
  type        = string
  default     = "default"
}

variable "ecr_repository_arns" {
  description = "ARNs of ECR repositories for CI/CD access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
