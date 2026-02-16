output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_group.arn
}

output "app_service_account_role_arn" {
  description = "ARN of the IRSA role for application service accounts"
  value       = aws_iam_role.app_service_account.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD IAM role"
  value       = aws_iam_role.cicd.arn
}
