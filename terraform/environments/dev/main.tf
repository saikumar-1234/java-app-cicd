# VPC module for dev
module "vpc" {
  source = "../../modules/vpc"
  env = "dev"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# EKS module for dev
module "eks" {
  source = "../../modules/eks"
  env = "dev"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 2
}

# ECR module for dev
module "ecr" {
  source = "../../modules/ecr"
  env = "dev"
}

# Output dev-specific values
output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}