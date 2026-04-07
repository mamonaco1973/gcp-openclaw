# ================================================================================
# FILE: openclaw.pkr.hcl
# ================================================================================
#
# Purpose:
#   Build a self-contained GCE image from Ubuntu 24.04 with:
#     - LXQt desktop + XRDP
#     - Google Chrome
#     - Cloud CLIs: gcloud, AWS CLI v2, Azure CLI
#     - Dev tools: Git, Terraform, Packer, VS Code
#     - Node.js 22, pnpm, OpenClaw
#     - LiteLLM proxy (Python venv)
#     - systemd services for LiteLLM and OpenClaw gateway
#
# Design:
#   - Base image: latest Canonical Ubuntu 24.04 from ubuntu-os-cloud.
#   - Fully self-contained — no dependency on a pre-built base image.
#   - Output image tagged in family "openclaw-images" for use by 03-openclaw.
#
# ================================================================================


# ================================================================================
# SECTION: Packer Plugin Configuration
# ================================================================================

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.1.6"
    }
  }
}


# ================================================================================
# SECTION: Locals
# ================================================================================

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}


# ================================================================================
# SECTION: Build-Time Variables
# ================================================================================

variable "project_id" {
  description = "GCP project ID that will own the image"
  type        = string
}

variable "zone" {
  description = "GCP zone used for the temporary build VM"
  type        = string
  default     = "us-central1-b"
}


# ================================================================================
# SECTION: Google Compute Builder Source
# ================================================================================

source "googlecompute" "openclaw" {
  project_id          = var.project_id
  zone                = var.zone
  source_image_family = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]
  ssh_username        = "ubuntu"
  machine_type        = "n2-standard-4"

  image_name   = "openclaw-image-${local.timestamp}"
  image_family = "openclaw-images"
  disk_size    = 64
}


# ================================================================================
# SECTION: Build Provisioners
# ================================================================================

build {
  sources = ["source.googlecompute.openclaw"]

  # Upload systemd service unit files and icon.
  provisioner "file" {
    source      = "./files/litellm.service"
    destination = "/tmp/litellm.service"
  }

  provisioner "file" {
    source      = "./files/openclaw-gateway.service"
    destination = "/tmp/openclaw-gateway.service"
  }

  provisioner "file" {
    source      = "./files/openclaw.png"
    destination = "/tmp/openclaw.png"
  }

  provisioner "file" {
    source      = "./files/xvfb.service"
    destination = "/tmp/xvfb.service"
  }

  # Remove snap, install base packages.
  provisioner "shell" {
    script          = "./scripts/01-packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install LXQt desktop environment.
  provisioner "shell" {
    script          = "./scripts/02-desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install XRDP and configure LXQt session.
  provisioner "shell" {
    script          = "./scripts/03-xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Google Chrome.
  provisioner "shell" {
    script          = "./scripts/04-chrome.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install cloud CLIs and dev tooling.
  provisioner "shell" {
    script          = "./scripts/05-tools.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Create the openclaw Linux user with sudo access.
  provisioner "shell" {
    script          = "./scripts/06-user.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Node.js 22, pnpm, and openclaw globally.
  provisioner "shell" {
    script          = "./scripts/07-node.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Create Python venv and install LiteLLM proxy.
  provisioner "shell" {
    script          = "./scripts/08-litellm.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install Python packages and system utilities for agent use.
  provisioner "shell" {
    script          = "./scripts/11-python-tools.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install OnlyOffice Desktop Editors.
  provisioner "shell" {
    script          = "./scripts/12-onlyoffice.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install GCP cost report and send-cost-report helper scripts.
  provisioner "shell" {
    script          = "./scripts/13-gcp-tools.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Run openclaw gateway briefly to stamp config metadata; configure model.
  provisioner "shell" {
    script          = "./scripts/09-openclaw-init.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install and enable systemd service units.
  provisioner "shell" {
    script          = "./scripts/10-services.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
