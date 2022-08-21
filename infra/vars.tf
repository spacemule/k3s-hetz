variable "hcloud_token" {
  type        = string
  description = "Project-specific API Key"
  sensitive   = true
}

variable "region" {
  default = "hel1"
  type    = string
}

variable "zone" {
  default = "eu-central"
  type    = string
}

variable "datacenter" {
  default = "hel1-dc2"
  type    = string
}

variable "ssh_pubkey" {
  type        = string
  description = "SSH public key for access to servers"
}

variable "control_planes" {
  type        = list(any)
  description = "List of instances by type"
  # Ex: ["cx11", "cx31]
}

variable "workers" {
  type        = list(any)
  description = "List of instances by type"
  # Ex: ["cx11", "cx31]
}

variable "network_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "services_cidr" {
  type = string
}

variable "redis_instance" {
  type    = string
  default = "cpx11"
}

variable "postgres_instance" {
  type    = string
  default = "cpx11"
}

variable "postgres_enabled" {
  default = false
  type    = bool
}

variable "redis_enabled" {
  default = false
  type    = bool
}

variable "psql_redis_separate" {
  default = false
  type    = bool
}

variable "k3s_token" {
  type    = string
  default = ""
}

variable "cluster_cidr" {
  type    = string
  default = "10.16.0.0/16"
}

variable "setup_complete" {
  type    = bool
  default = true
}