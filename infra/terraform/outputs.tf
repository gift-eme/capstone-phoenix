output "server_public_ip" {
  description = "k3s control-plane public IP — for SSH and kubeconfig"
  value       = module.compute.server_public_ip
}

output "server_private_ip" {
  description = "k3s control-plane private IP — used by workers to join"
  value       = module.compute.server_private_ip
}

output "worker_public_ips" {
  description = "k3s agent public IPs — for SSH"
  value       = module.compute.worker_public_ips
}

output "worker_private_ips" {
  description = "k3s agent private IPs"
  value       = module.compute.worker_private_ips
}

output "admin_cidrs" {
  description = "CIDRs allowed to SSH/kubectl in — consumed by Ansible so it isn't hardcoded a second time"
  value       = var.admin_cidrs
}

output "vpc_cidr" {
  description = "VPC CIDR — consumed by Ansible for node-to-node ufw rules"
  value       = var.vpc_cidr
}
