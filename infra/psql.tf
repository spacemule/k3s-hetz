data "hcloud_image" "postgres" {
  with_selector = "type=db"
}

resource "hcloud_server" "postgres" {
  name               = "postgres"
  server_type        = var.postgres_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.postgres.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
#  user_data          = data.cloudinit_config.postgres-init.rendered
  user_data          = data.cloudinit_config.redis-init.rendered
  firewall_ids       = []

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server_network" "postgres-ip" {
  server_id  = hcloud_server.postgres.id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.services_cidr, 3 )
}

resource "hcloud_network_route" "wireguard" {
  destination = "192.168.10.10/32"
  gateway     = "10.15.1.3"
  network_id  = hcloud_network.kube-net.id
}

resource "hcloud_network_route" "dns" {
  destination = "10.42.0.1/32"
  gateway     = "10.15.1.3"
  network_id  = hcloud_network.kube-net.id
}

data "cloudinit_config" "postgres-init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/microos.yaml.tpl",
      {
        hostname          = "postgres"
        sshAuthorizedKeys = [var.ssh_pubkey]
      }
    )
  }
}