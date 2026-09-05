# ================================================================================
# FILE: networking.tf
# ================================================================================
#
# Purpose:
#   Define baseline networking for the OpenClaw environment:
#     - Custom-mode VPC (no auto-created subnets)
#     - Single subnet in us-east4
#     - Cloud Router + Cloud NAT (commented out - see below)
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
  region        = "us-east4"
  network       = google_compute_network.openclaw_vpc.id
  ip_cidr_range = "10.0.0.0/24"
}


# ==============================================================================
# SECTION: Cloud Router + Cloud NAT -- DISABLED
# ==============================================================================
#
# Both are commented out because nothing in this project ever used them.
# Cloud NAT only carries egress for instances that have NO external IP, and
# the OpenClaw VM is given one (compute.tf, access_config {}) because RDP
# connects straight to it on 3389. Traffic from a VM with an external IP
# leaves through that IP directly and never reaches the NAT gateway.
#
# The Packer build VM does not use it either: the builder sets no network or
# subnetwork, so it lands in the project default VPC, not openclaw-vpc.
#
# The Cloud Router existed only to host the NAT -- no BGP, no interconnect.
#
# Kept here rather than deleted: if the external IP is ever dropped in favour
# of IAP-tunnelled RDP, these come back verbatim to restore outbound access.
#
# # ================================================================================
# # SECTION: Cloud Router
# # ================================================================================
#
# resource "google_compute_router" "openclaw_router" {
#   name    = "openclaw-router"
#   network = google_compute_network.openclaw_vpc.id
#   region  = "us-east4"
# }
#
#
# # ================================================================================
# # SECTION: Cloud NAT
# # ================================================================================
#
# resource "google_compute_router_nat" "openclaw_nat" {
#   name   = "openclaw-nat"
#   router = google_compute_router.openclaw_router.name
#   region = google_compute_router.openclaw_router.region
#
#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#
#   log_config {
#     enable = true
#     filter = "ALL"
#   }
# }
