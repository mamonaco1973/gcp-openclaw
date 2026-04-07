# ================================================================================
# FILE: compute.tf
# ================================================================================
#
# Purpose:
#   Firewall rules and GCE instance for the OpenClaw host.
#
# Design:
#   - Port 3389 open for direct RDP access.
#   - All outbound allowed for Vertex AI API calls and package updates.
#   - Boot image resolved from Packer-built openclaw-images family.
#
# ================================================================================


# ================================================================================
# SECTION: Firewall — RDP Inbound
# ================================================================================

resource "google_compute_firewall" "allow_rdp" {
  name    = "openclaw-allow-rdp"
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  target_tags   = ["openclaw-allow-rdp"]
  source_ranges = ["0.0.0.0/0"]
}


# ================================================================================
# SECTION: GCE Instance
# ================================================================================

resource "google_compute_instance" "openclaw" {
  name         = "openclaw-host"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.openclaw.self_link
      size  = 128
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_name

    # Ephemeral public IP for RDP access
    access_config {}
  }

  metadata = {
    startup-script = templatefile("${path.module}/scripts/startup.sh", {
      primary_model   = var.primary_model
      secondary_model = var.secondary_model
      project_id      = local.credentials.project_id
    })
  }

  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["openclaw-allow-rdp"]

  labels = { name = "openclaw-host" }
}
