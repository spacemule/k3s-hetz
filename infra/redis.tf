resource "hcloud_server" "redis" {
  name               = "redis"
  server_type        = var.redis_instance
  placement_group_id = hcloud_placement_group.k8s-places.id
  image              = data.hcloud_image.microOS.id
  location           = "hel1"
  ssh_keys           = [hcloud_ssh_key.k8s-key.id]
  user_data          = data.cloudinit_config.redis-init.rendered
#  firewall_ids       = [hcloud_firewall.default.id]
  firewall_ids       = []

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  depends_on = [
    hcloud_network_subnet.k8s-sub
  ]
}

resource "hcloud_server_network" "redis-ip" {
  server_id  = hcloud_server.redis.id
  network_id = hcloud_network.kube-net.id
  ip         = cidrhost(var.services_cidr, 2 )
}

data "cloudinit_config" "redis-init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile(
      "${path.module}/templates/microos.yaml.tpl",
      {
        hostname          = "redis"
        sshAuthorizedKeys = [var.ssh_pubkey]
      }
    )
  }
}