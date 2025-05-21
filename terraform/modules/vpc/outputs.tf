# Output VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Output public subnet IDs
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}