terraform {
  required_version = "0.15.1"
  # terraform init -backend-config=backend.hcl
  backend "remote" {}
}
locals {
  cluster_type = "deploy-service"
}

provider "google" {
  version = "~> 3.42.0"
  region = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  load_config_file = false
  host = "https://${module.gke.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "gke" {
  source = "terraform-google-modules/kubernetes-engine/google"
  project_id = var.project_id
  name = "${local.cluster_type}-cluster${var.cluster_name_suffix}"
  region = var.region
  network = var.network
  subnetwork = var.subnetwork

  ip_range_pods = var.ip_range_pods
  ip_range_services = var.ip_range_services
  create_service_account = false
  service_account = var.compute_engine_service_account
}

resource "kubernetes_pod" "nginx-example" {
  metadata {
    name = "nginx-example"

    labels = {
      maintained_by = "terraform"
      app = "nginx-example"
    }
  }

  spec {
    container {
      image = "nginx:1.7.9"
      name = "nginx-example"
    }
  }

  depends_on = [
    module.gke]
}

resource "kubernetes_service" "nginx-example" {
  metadata {
    name = "terraform-example"
  }

  spec {
    selector = {
      app = kubernetes_pod.nginx-example.metadata[0].labels.app
    }

    session_affinity = "ClientIP"

    port {
      port = 8080
      target_port = 80
    }

    type = "LoadBalancer"
  }

  depends_on = [
    module.gke]
}

variable "project_id" {
  description = "The project ID to host the cluster in"
}

variable "cluster_name_suffix" {
  description = "A suffix to append to the default cluster name"
  default = ""
}

variable "region" {
  description = "The region to host the cluster in"
}

variable "network" {
  description = "The VPC network to host the cluster in"
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster in"
}

variable "ip_range_pods" {
  description = "The secondary ip range to use for pods"
}

variable "ip_range_services" {
  description = "The secondary ip range to use for services"
}

variable "compute_engine_service_account" {
  description = "Service account to associate to the nodes in the cluster"
}

output "kubernetes_endpoint" {
  sensitive = true
  value = module.gke.endpoint
}

output "client_token" {
  sensitive = true
  value = base64encode(data.google_client_config.default.access_token)
}

output "ca_certificate" {
  value = module.gke.ca_certificate
}

output "service_account" {
  description = "The default service account used for running nodes."
  value = module.gke.service_account
}
