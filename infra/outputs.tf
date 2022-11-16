output "control_plane_ips" {
  value = hcloud_server.control-plane[*].ipv4_address
}

#output "worker_ips" {
#  value = hcloud_server.worker[*].ipv4_address
#}
#
output "db_ip" {
  value = var.postgres_enabled == true ? hcloud_server_network.postgres-ip[0].ip : null
}

output "hcloud_network" {
  value = hcloud_network.kube-net.id
}

output "hcloud_master_id" {
  value = hcloud_server.control-plane[0].id
}

#
#output "redis_ip" {
#  value = hcloud_server_network.redis-ip.ip
#}
#
#output "lb_ip" {
#  value = hcloud_load_balancer.k3s_lb.ipv4
#}