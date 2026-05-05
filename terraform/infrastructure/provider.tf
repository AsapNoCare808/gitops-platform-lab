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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

}

# Configure the AWS Provider
provider "aws" {
  region                   = "eu-west-3"
  shared_credentials_files = ["/Users/maxto/.aws/credentials"]
}