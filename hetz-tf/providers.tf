terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.6.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.36.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}

provider "hcloud" {
  token = var.hcloud_token
}