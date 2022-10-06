data "hcloud_image" "postgres" {
  count         = var.postgres_enabled == true ? 1 : 0
  with_selector = "service=db"
}

resource "hcloud_server" "postgres" {
  count              = var.postgres_enabled == true ? 1 : 0
  name               = "postgres"
  server_type        = var.postgres_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.postgres[0].id
  location           = var.region
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.postgres-init[count.index].rendered
  firewall_ids       = [hcloud_firewall.default.id]

  public_net {
    ipv4_enabled = var.setup_complete == false ? true : false
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.kube-net.id
    ip         = cidrhost(var.services_cidr, 3 )
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server_network" "postgres-ip" {
  count      = var.postgres_enabled == true ? 1 : 0
  server_id  = hcloud_server.postgres[0].id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.services_cidr, 3 )
}

data "cloudinit_config" "postgres-init" {
  count         = var.postgres_enabled == true ? 1 : 0
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/microos-db.yaml.tpl",
      {
        hostname          = "db"
        sshAuthorizedKeys = [var.ssh_pubkey]
        default_route_ip  = cidrhost(var.network_cidr, 1)
        private_ip        = cidrhost(var.services_cidr, 3 )
      }
    )
  }
}