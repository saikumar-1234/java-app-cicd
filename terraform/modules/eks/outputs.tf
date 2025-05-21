# Output EKS cluster name
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}