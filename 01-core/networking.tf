# ================================================================================
# FILE: networking.tf
# ================================================================================
#
# Purpose:
#   Define baseline networking for the OpenClaw environment:
#     - Custom-mode VPC (no auto-created subnets)
#     - Single subnet in us-central1
#     - Cloud Router + Cloud NAT for outbound internet access
#
# ================================================================================


# ================================================================================
# SECTION: VPC
# ================================================================================

resource "google_compute_network" "openclaw_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}


# ================================================================================
# SECTION: Subnet
# ================================================================================

resource "google_compute_subnetwork" "openclaw_subnet" {
  name          = var.subnet_name
  region        = "us-central1"
  network       = google_compute_network.openclaw_vpc.id
  ip_cidr_range = "10.0.0.0/24"
}


# ================================================================================
# SECTION: Cloud Router
# ================================================================================

resource "google_compute_router" "openclaw_router" {
  name    = "openclaw-router"
  network = google_compute_network.openclaw_vpc.id
  region  = "us-central1"
}


# ================================================================================
# SECTION: Cloud NAT
# ================================================================================

resource "google_compute_router_nat" "openclaw_nat" {
  name   = "openclaw-nat"
  router = google_compute_router.openclaw_router.name
  region = google_compute_router.openclaw_router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}
