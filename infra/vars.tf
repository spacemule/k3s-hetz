variable "hcloud_token" {
  default = ""
  type = string
  description = "Project-specific API Key"
  sensitive = true
}

variable "ssh_pubkey" {
  default = ""
  type = string
  description = "SSH public key for access to servers"
}

variable "control_plane_count" {
  type = number
  default = 1
  description = "Number of control planes"
}

variable "standard_worker_count" {
  type = number
  default = 2
  description = "Number of standard worker nodes"
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

variable "standard_worker_instance" {
  type = string
  default = "cpx21"
}

variable "control_plane_instance" {
  type = string
  default = "cx21"
}

variable "redis_instance" {
  type = string
  default = "cpx11"
}

variable "postgres_instance" {
  type = string
  default = "cpx11"
}