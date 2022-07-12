output "control_plane_ips" {
  value = module.k3s.control_plane_ips
}

output "worker_ips" {
  value = module.k3s.worker_ips
}