# Create EKS cluster
resource "aws_eks_cluster" "main" {
  name = "${var.env}-eks-cluster"
  role_arn = aws_iam_role.eks.arn
  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = [aws_security_group.eks.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks]
}

# Create EKS node group
resource "aws_eks_node_group" "main" {
  cluster_name = aws_eks_cluster.main.name
  node_group_name = "${var.env}-node-group"
  node_role_arn = aws_iam_role.node.arn
  subnet_ids = var.subnet_ids
  scaling_config {
    desired_size = var.node_count
    max_size = var.node_count + 2
    min_size = var.node_count
  }
  instance_types = ["t3.medium"]
  depends_on = [aws_iam_role_policy_attachment.node]
}

# IAM role for EKS cluster
resource "aws_iam_role" "eks" {
  name = "${var.env}-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Attach EKS cluster policy
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks.name
}

# IAM role for EKS nodes
resource "aws_iam_role" "node" {
  name = "${var.env}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach EKS worker node policy
resource "aws_iam_role_policy_attachment" "node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.node.name
}

# Security group for EKS
resource "aws_security_group" "eks" {
  vpc_id = var.vpc_id
  name = "${var.env}-eks-sg"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.env}-eks-sg"
  }
}