# Environment name (dev, stage, prod)
variable "env" {
  type = string
}

# VPC CIDR block
variable "vpc_cidr" {
  type = string
}

# Public subnet CIDR blocks
variable "public_subnet_cidrs" {
  type = list(string)
}

# Availability zones for subnets
variable "availability_zones" {
  type = list(string)
}