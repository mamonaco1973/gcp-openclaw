output "instance_id" {
  description = "Instance ID for SSM Session Manager connection"
  value       = aws_instance.openclaw.id
}

output "public_ip" {
  description = "Public IP for direct RDP access (port 3389)"
  value       = aws_instance.openclaw.public_ip
}

output "public_dns" {
  description = "Public FQDN for direct RDP access (port 3389)"
  value       = aws_instance.openclaw.public_dns
}
