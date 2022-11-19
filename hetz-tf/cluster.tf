module "k3s" {
  source           = "../infra/"
  control_planes   = ["cpx11"]
  network_cidr     = "10.0.0.0/12"
  services_cidr    = "10.15.1.0/24"
  subnet_cidr      = "10.1.0.0/16"
  workers          = ["cpx21"]
  hcloud_token     = var.hcloud_token
  ssh_pubkey       = var.ssh_pubkey
  postgres_enabled = false
}

resource "hcloud_firewall" "cluster_apps" {
  name = "cluster_apps"
  # Wireguard
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820"
    source_ips = [
      "0.0.0.0/0",
    ]
  }

  # Syncthing
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22000"
    source_ips = [
      "0.0.0.0/0",
    ]
  }
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "22001"
    source_ips = [
      "0.0.0.0/0",
    ]
  }
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "21017"
    source_ips = [
      "0.0.0.0/0",
    ]
  }

  apply_to {
    label_selector = "type=master"
  }
}

