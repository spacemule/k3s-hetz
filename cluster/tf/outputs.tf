output "control_plane_ips" {
  value = module.k3s.control_plane_ips
}

output "worker_ips" {
  value = module.k3s.worker_ips
}

output "postgres_ip" {
  value = module.k3s.postgres_ip
}

output "redis_ip" {
  value = module.k3s.redis_ip
}