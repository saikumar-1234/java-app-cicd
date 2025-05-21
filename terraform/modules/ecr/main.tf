# Create ECR repository
resource "aws_ecr_repository" "main" {
  name = "${var.env}-java-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "${var.env}-java-app-ecr"
  }
}