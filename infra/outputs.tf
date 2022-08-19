output "control_plane_ips" {
  value = hcloud_server.control-plane[*].ipv4_address
}

#output "worker_ips" {
#  value = hcloud_server.worker[*].ipv4_address
#}
#
#output "postgres_ip" {
#  value = hcloud_server_network.postgres-ip.ip
#}
#
#output "redis_ip" {
#  value = hcloud_server_network.redis-ip.ip
#}
#
#output "lb_ip" {
#  value = hcloud_load_balancer.k3s_lb.ipv4
#}