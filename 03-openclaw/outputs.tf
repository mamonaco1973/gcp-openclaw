output "instance_name" {
  description = "GCE instance name"
  value       = google_compute_instance.openclaw.name
}

output "public_ip" {
  description = "Public IP for direct RDP access (port 3389)"
  value       = google_compute_instance.openclaw.network_interface[0].access_config[0].nat_ip
}

output "credentials_secret_id" {
  description = "Secret Manager secret holding the openclaw username/password"
  value       = google_secret_manager_secret.openclaw_credentials.secret_id
}
