locals {
  hetzner_ips = [
    "169.254.169.254/32",
    "213.239.246.1/32",
    "127.0.0.1/32",
    var.network_cidr,
  ]
}

data "hcloud_image" "microOS" {
  with_selector = "type=base"
}

resource "hcloud_network" "kube-net" {
  ip_range = var.network_cidr
  # 10.0.0.0 - 10.15.255.255
  name     = "kube-net"
}

resource "hcloud_network_subnet" "services-sub" {
  ip_range     = var.services_cidr
  network_id   = hcloud_network.kube-net.id
  network_zone = "eu-central"
  type         = "cloud"
}

resource "hcloud_network_subnet" "k8s-sub" {
  ip_range     = var.subnet_cidr
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
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = local.hetzner_ips
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = local.hetzner_ips
  }

  rule {
    direction = "out"
    protocol = "tcp"
    port     = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "out"
    protocol = "udp"
    port     = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "out"
    protocol = "icmp"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
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
  server_type        = var.control_plane_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.microOS.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-init[count.index].rendered
  firewall_ids       = []
  labels = {
    "job" : "k8s"
    "type" : "master"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server" "standard-worker" {
  count              = var.standard_worker_count
  name               = "k3s-node-${count.index + var.control_plane_count}"
  server_type        = var.standard_worker_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.microOS.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-init[count.index + var.control_plane_count].rendered
  firewall_ids       = []
  labels = {
    "job": "k8s"
    "type": "worker"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server" "big-worker" {
  count              = var.big_worker_count
  name               = "k3s-node-${count.index + var.control_plane_count + var.standard_worker_count}"
  server_type        = var.big_worker_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.microOS.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-init[count.index + var.control_plane_count + var.standard_worker_count].rendered
  firewall_ids       = []
  labels = {
    "job": "k8s"
    "type": "worker"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server_network" "control-plane-ips" {
  count      = length(hcloud_server.control-plane)
  server_id  = hcloud_server.control-plane[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.subnet_cidr, count.index + 2 )
}

resource "hcloud_server_network" "standard-worker-ips" {
  count      = length(hcloud_server.standard-worker)
  server_id  = hcloud_server.standard-worker[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.subnet_cidr, var.control_plane_count + count.index + 2 )
}

resource "hcloud_server_network" "big-worker-ips" {
  count      = length(hcloud_server.big-worker)
  server_id  = hcloud_server.big-worker[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.subnet_cidr, var.control_plane_count + var.standard_worker_count + count.index + 2 )
}

data "cloudinit_config" "k3s-init" {
  count         = var.standard_worker_count + var.control_plane_count + var.big_worker_count
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