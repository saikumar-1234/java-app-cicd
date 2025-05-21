# VPC module for prod
module "vpc" {
  source = "../../modules/vpc"
  env = "prod"
  vpc_cidr = "10.2.0.0/16"
  public_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# EKS module for prod
module "eks" {
  source = "../../modules/eks"
  env = "prod"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 4
}

# ECR module for prod
module "ecr" {
  source = "../../modules/ecr"
  env = "prod"
}

# Output prod-specific values
output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}