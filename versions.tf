terraform {
  required_version = ">= 1.0.0"

  required_providers {
    github = {
      source  = "hashicorp/github"
      version = "~> 6.6.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
  # backend "aws-s3" {
  #     bucket         = "my-terraform-state-bucket"
  #     key            = "terraform.tfstate"
  #     region         = "us-west-2"
  #     encrypt        = true
  #     dynamodb_table = "terraform-locks"
  # }
}