variable "manifest_repo_private_key" {
  type = string
  description = "RO SSH Key for git"
}

variable "sealed_secrets_tls_key" {
  type = string
}

variable "sealed_secrets_tls_crt" {
  type = string
}

variable "argocd_app_of_apps_name" {
  type        = string
  default     = "app-of-apps"
  description = ""
}

variable "argocd_app_of_apps_path" {
  type        = string
  default     = "cluster/apps/app-of-apps"
}

variable "argocd_app_of_apps_prune" {
  type        = bool
  default     = true
  description = "Let argocd delete orphaned resources"
}

variable "argocd_app_of_apps_values_file" {
  type        = string
  default     = "values.yaml"
}

variable "argocd_app_of_apps_target_revision" {
  type        = string
  default     = "main"
  description = "Branch/SHA of Git repo with desired manifests"
}

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