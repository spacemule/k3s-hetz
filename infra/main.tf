locals {
  hetzner_ips = [
    "169.254.169.254/32",
    "213.239.246.1/32",
    "127.0.0.1/32",
    var.network_cidr,
  ]
}

resource "hcloud_network" "kube-net" {
  ip_range = var.network_cidr
  # 10.0.0.0 - 10.15.255.255
  name     = "kube-net"
}

resource "hcloud_network_subnet" "all-sub" {
  ip_range     = var.network_cidr
  network_id   = hcloud_network.kube-net.id
  network_zone = var.zone
  type         = "cloud"
}

#resource "hcloud_network_subnet" "services-sub" {
#  ip_range     = var.services_cidr
#  network_id   = hcloud_network.kube-net.id
#  network_zone = var.zone
#  type         = "cloud"
#}
#
#resource "hcloud_network_subnet" "k8s-sub" {
#  ip_range     = var.subnet_cidr
#  network_id   = hcloud_network.kube-net.id
#  network_zone = var.zone
#  type         = "cloud"
#}

resource "hcloud_network_route" "gateway" {
  destination = "0.0.0.0/0"
  gateway     = hcloud_server_network.control-plane-ips[0].ip
  network_id  = hcloud_network.kube-net.id
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
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  apply_to {
    label_selector = "type=master"
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
  #Allow all node ports if exposed
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30000-32767"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "30000-32767"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  apply_to {
    label_selector = "type=master"
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

  apply_to {
    label_selector = "type=master"
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

resource "random_id" "ip-name" {
  keepers = {
    datacenter = var.datacenter
  }
  byte_length = 4
}
resource "hcloud_primary_ip" "control_plane" {
  name          = "control_plane_${random_id.ip-name.hex}"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  datacenter    = random_id.ip-name.keepers.datacenter
}

resource "hcloud_server" "control-plane" {
  count              = length(var.control_planes)
  name               = "k3s-master-${count.index}"
  server_type        = var.control_planes[count.index]
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = "rocky-9"
  location           = var.region
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-control-plane-init[count.index].rendered

  labels = {
    "job" : "k8s"
    "type" : "master"
  }

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_plane.id
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube-net.id
    ip         = cidrhost(var.subnet_cidr, count.index + 1 )
  }

  depends_on = [
    hcloud_network.kube-net,
  ]

  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}

resource "time_sleep" "server_start" {
  depends_on      = [hcloud_server.control-plane]
  create_duration = "300s"
}

resource "hcloud_server" "worker" {
  count              = length(var.workers)
  name               = "k3s-worker-${count.index}"
  server_type        = var.workers[count.index]
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = "rocky-9"
  location           = var.region
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.k3s-worker-init[count.index].rendered
  labels = {
    "job" : "k8s"
    "type" : "worker"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube-net.id
    ip         = cidrhost(var.subnet_cidr, length(var.control_planes) + count.index + 1 )
  }

  lifecycle {
    ignore_changes = [user_data]
  }
  depends_on = [
    hcloud_network.kube-net,
    time_sleep.server_start,
  ]
}

resource "hcloud_server_network" "control-plane-ips" {
  count      = length(hcloud_server.control-plane)
  server_id  = hcloud_server.control-plane[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.subnet_cidr, count.index + 1 )
}

resource "hcloud_server_network" "worker-ips" {
  count      = length(hcloud_server.worker)
  server_id  = hcloud_server.worker[count.index].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.subnet_cidr, length(var.control_planes) + count.index + 1 )
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

data "cloudinit_config" "k3s-control-plane-init" {
  count         = length(var.control_planes)
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/rocky-k3s-master.yaml.tpl",
      {
        hostname          = "k3s-master-${count.index}"
        sshAuthorizedKeys = [var.ssh_pubkey]
        k3s_token         = var.k3s_token == "" ? random_password.k3s_token.result : var.k3s_token
        k3s_version        = var.k3s_version
        control_ip        = cidrhost(var.subnet_cidr, count.index + 1 )
        cluster_cidr      = var.cluster_cidr
        public_ip         = hcloud_primary_ip.control_plane.ip_address
        region            = var.region
        private_network   = hcloud_network.kube-net.name
        hcloud_key        = var.hcloud_token
      }
    )
  }
}

data "cloudinit_config" "k3s-worker-init" {
  count         = length(var.workers)
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/rocky-k3s-worker.yaml.tpl",
      {
        hostname          = "k3s-worker-${count.index}"
        sshAuthorizedKeys = [var.ssh_pubkey]
        k3s_token         = var.k3s_token == "" ? random_password.k3s_token.result : var.k3s_token
        k3s_version        = var.k3s_version
        default_route_ip  = cidrhost(var.network_cidr, 1)
        control_ip        = hcloud_server_network.control-plane-ips[0].ip
        node_ip           = cidrhost(var.subnet_cidr, length(var.control_planes) + count.index + 1 )

      }
    )
  }
}