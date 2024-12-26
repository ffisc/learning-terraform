terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

// a provider is what gives you access to resources, so a provider is necessary
provider "aws" {
  region  = "us-west-2"
}
