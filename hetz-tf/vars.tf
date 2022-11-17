variable "k3s_token" {
  type = string
}

variable "hcloud_token" {
  type = string
}

variable "ssh_pubkey" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKlBDIjDIpkWjZNlvTn199HBv6NBgyx0zSASrV77hfCh noah@spacemule"

}
