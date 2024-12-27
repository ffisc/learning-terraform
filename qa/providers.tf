terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

// a provider is what gives you access to resources, so a provider is necessary (but only in the root module, in other cases add only if necessary)
provider "aws" {
  region  = "us-west-2"
}
