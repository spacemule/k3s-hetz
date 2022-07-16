output "control_plane_ips" {
  value = hcloud_server.control-plane[*].ipv4_address
}

output "worker_ips" {
  value = hcloud_server.standard-worker[*].ipv4_address
}

output "big_worker_ips" {
  value = hcloud_server.big-worker[*].ipv4_address
}

output "postgres_ip" {
  value = hcloud_server.postgres.ipv4_address
}

#output "redis_ip" {
#  value = hcloud_server.redis.ipv4_address
#}