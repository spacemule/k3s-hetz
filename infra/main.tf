locals {
  hetzner_ips =[
 "169.254.169.254/32",
  "213.239.246.1/32",
  "10.0.0.0/8",
  "127.0.0.1/32"
  ]
}

data "hcloud_image" "k3-base" {
  with_selector = "type=base"
}

resource "hcloud_network" "kube-net" {
  ip_range = "10.0.0.0/8"
  # 10.0.0.0 - 10.15.255.255
  name     = "kube-net"
}

resource "hcloud_network_subnet" "k8s-sub" {
  ip_range     = "10.0.0.0/16"
  network_id   = hcloud_network.kube-net.id
  network_zone = "eu-central"
  type         = "cloud"
}

resource hcloud_firewall "default" {
  name = "default"

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol = "tcp"
    port = "any"
    source_ips = local.hetzner_ips
  }

  rule {
    direction = "in"
    protocol = "udp"
    port = "any"
    source_ips = local.hetzner_ips
  }
}

resource "hcloud_firewall" "k8s-control" {
  name = "k8s-control"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_firewall" "k8s-wall-of-china" {
  name = "k8s-wall-of-china"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_ssh_key" "k8s-key" {
  name       = "k8s-key"
  public_key = var.ssh_pubkey
}

resource "hcloud_placement_group" "k8s-places" {
  name = "k8s-places"
  type = "spread"
}

resource "hcloud_server" "control-plane" {
  count              = var.control_plane_count
  name               = "k3s-node-${count.index}"
  server_type        = "cpx11"
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.k3-base.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-init[count.index].rendered
  firewall_ids = []
#  firewall_ids       = [hcloud_firewall.k8s-control.id, hcloud_firewall.default.id]

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server" "standard-worker" {
  count              = var.standard_worker_count
  name               = "k3s-node-${count.index + var.control_plane_count}"
  server_type        = "cpx21"
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.k3-base.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-init[count.index + var.control_plane_count].rendered
  firewall_ids = []
  #  firewall_ids       = [hcloud_firewall.k8s-wall-of-china.id, hcloud_firewall.default.id]

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server_network" "control-plane-ips" {
  count      = length(hcloud_server.control-plane)
  server_id  = hcloud_server.control-plane[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = "10.0.0.${2 + count.index}"
}

resource "hcloud_server_network" "worker-ips" {
  count      = length(hcloud_server.standard-worker)
  server_id  = hcloud_server.standard-worker[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = "10.0.0.${2 + var.control_plane_count + count.index}"
}

data "cloudinit_config" "k3s-init" {
  count         = var.standard_worker_count + var.control_plane_count
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/microos-k3s.yaml.tpl",
      {
        hostname          = "k3s-node-${count.index}"
        sshAuthorizedKeys = [var.ssh_pubkey]
      }
    )
  }
}