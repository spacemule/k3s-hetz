resource "hcloud_load_balancer" "k3s_lb" {
  load_balancer_type = "lb11"
  name               = "kube-net"
  location           = "hel1"
}

resource "hcloud_load_balancer_network" "lb_ip" {
  load_balancer_id = hcloud_load_balancer.k3s_lb.id
  network_id       = hcloud_network.kube-net.id
  ip               = cidrhost(var.services_cidr, 4 )
}

resource "hcloud_load_balancer_target" "k3s_targets" {

  load_balancer_id = hcloud_load_balancer.k3s_lb.id
  type             = "label_selector"
  label_selector   = "job=k8s"
}