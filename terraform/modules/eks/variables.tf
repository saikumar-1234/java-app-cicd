# Environment name
variable "env" {
  type = string
}

# Subnet IDs for EKS
variable "subnet_ids" {
  type = list(string)
}

# VPC ID
variable "vpc_id" {
  type = string
}

# Number of nodes
variable "node_count" {
  type = number
}