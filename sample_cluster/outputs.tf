output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = [for instance in aws_instance.app_server : instance.id]
}

output "instance_public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = [for instance in aws_instance.app_server : instance.public_ip]
}
