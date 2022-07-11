output "control_plane_ips" {
  value = hcloud_server.control-plane[*].ipv4_address
}

output "worker_ips" {
  value = hcloud_server.standard-worker[*].ipv4_address
}