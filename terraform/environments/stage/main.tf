# VPC module for stage
module "vpc" {
  source = "../../modules/vpc"
  env = "stage"
  vpc_cidr = "10.1.0.0/16"
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# EKS module for stage
module "eks" {
  source = "../../modules/eks"
  env = "stage"
  subnet_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
  node_count = 3
}

# ECR module for stage
module "ecr" {
  source = "../../modules/ecr"
  env = "stage"
}

# Output stage-specific values
output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}