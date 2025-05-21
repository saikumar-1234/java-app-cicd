# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Module for dev environment
module "dev" {
  source = "./environments/dev"
}

# Module for stage environment
module "stage" {
  source = "./environments/stage"
}

# Module for prod environment
module "prod" {
  source = "./environments/prod"
}