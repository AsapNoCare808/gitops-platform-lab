terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket = "my-bucket-maxto-platform.cloud" # Doit être le même que le nom du bucket créé ci-dessus
    key    = "infrastructure/terraform.tfstate"
    region = "eu-west-3"
  }
}

# Configure the AWS Provider
provider "aws" {
  region                   = "eu-west-3"
  shared_credentials_files = ["/Users/maxto/.aws/credentials"]
}