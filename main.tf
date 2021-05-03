terraform {
  required_version = "0.15.1"
  # terraform init -backend-config=backend.hcl
  backend "remote" {}
}

locals {
  cluster_type = "deploy-service"
}

variable "region" {
  default = ""
}
provider "google" {
  version = "~> 3.42.0"
  region  = var.region
}

data "google_client_config" "default" {}

output "project" {
  value = data.google_client_config.default.project
}