terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # This uses the latest stable AWS features
    }
  }
}

provider "aws" {
  region = "us-west-2" # This must match where your TGW lives
}