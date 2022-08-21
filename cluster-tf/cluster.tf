module "k3s" {
  source         = "../infra/"
  control_planes = ["cpx11"]
  network_cidr   = "10.0.0.0/12"
  services_cidr  = "10.15.1.0/24"
  subnet_cidr    = "10.0.0.0/16"
  workers        = ["cpx11"]
  hcloud_token   = var.hcloud_token
  ssh_pubkey     = var.ssh_pubkey
  setup_complete = true
}

