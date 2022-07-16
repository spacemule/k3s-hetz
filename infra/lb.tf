resource "hcloud_load_balancer" "kube-lb" {
  delete_protection  = false
  labels             = {
    "hcloud-ccm/service-uid" = "d251ad66-cf94-468d-8574-fe178fd7fff6"
  }
  load_balancer_type = "lb11"
  location           = "hel1"
  name               = "kube-lb"
  network_zone       = "eu-central"

  algorithm {
    type = "round_robin"
  }
}

resource "hcloud_load_balancer_network" "kube-lb-net" {
  load_balancer_id = hcloud_load_balancer.kube-lb.id
  network_id = hcloud_network.kube-net.id
  ip = cidrhost(var.services_cidr, 100 )
}