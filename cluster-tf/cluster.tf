module "k3s" {
  source         = "../infra/"
  control_planes = ["cpx11"]
  network_cidr   = "10.0.0.0/12"
  services_cidr  = "10.15.1.0/24"
  subnet_cidr    = "10.0.0.0/16"
  workers        = ["cpx11"]
  hcloud_token   = var.hcloud_token
  k3s_token      = var.k3s_token
  ssh_pubkey     = var.ssh_pubkey
}