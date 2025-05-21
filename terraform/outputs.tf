# Output for dev EKS cluster name
output "dev_eks_cluster_name" {
  value = module.dev.eks_cluster_name
}

# Output for dev ECR repository URL
output "dev_ecr_repository_url" {
  value = module.dev.ecr_repository_url
}

# Output for stage EKS cluster name
output "stage_eks_cluster_name" {
  value = module.stage.eks_cluster_name
}

# Output for stage ECR repository URL
output "stage_ecr_repository_url" {
  value = module.stage.ecr_repository_url
}

# Output for prod EKS cluster name
output "prod_eks_cluster_name" {
  value = module.prod.eks_cluster_name
}

# Output for prod ECR repository URL
output "prod_ecr_repository_url" {
  value = module.prod.ecr_repository_url
}