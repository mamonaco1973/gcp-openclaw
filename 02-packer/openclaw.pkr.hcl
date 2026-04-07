# ================================================================================
# FILE: openclaw.pkr.hcl
# ================================================================================
#
# Purpose:
#   Build a self-contained AMI from Ubuntu 24.04 with:
#     - LXQt desktop + XRDP
#     - Google Chrome
#     - Cloud CLIs: AWS CLI v2, Azure CLI, Google Cloud SDK
#     - Dev tools: Git, Terraform, Packer, VS Code
#     - Node.js 22, pnpm, OpenClaw
#     - LiteLLM proxy (Python venv)
#     - systemd services for LiteLLM and OpenClaw gateway
#
# Design:
#   - Base image: latest Canonical Ubuntu 24.04 (Noble) AMI.
#   - Fully self-contained — no dependency on a pre-built base AMI.
#   - Output AMI tagged "openclaw_ami" for use by 03-openclaw Terraform.
#   - Builder uses pub-subnet-1 (public subnet) for SSH access during build.
#
# ================================================================================


# ================================================================================
# SECTION: Packer Plugin Configuration
# ================================================================================

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}


# ================================================================================
# SECTION: Base Ubuntu 24.04 AMI Lookup
# ================================================================================

data "amazon-ami" "ubuntu_2404" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}


# ================================================================================
# SECTION: Build-Time Variables
# ================================================================================

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "m5.xlarge"
}

variable "vpc_id" {
  description = "VPC ID (clawd-vpc) resolved by apply.sh from 01-core outputs"
  default     = ""
}

variable "subnet_id" {
  description = "Public subnet ID (pub-subnet-1) for SSH access during build"
  default     = ""
}


# ================================================================================
# SECTION: Amazon-EBS Builder Source
# ================================================================================

source "amazon-ebs" "openclaw" {
  region        = var.region
  instance_type = var.instance_type
  source_ami    = data.amazon-ami.ubuntu_2404.id
  ssh_username  = "ubuntu"
  ssh_interface = "public_ip"
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id

  # Timestamped name allows multiple versions to coexist.
  # Terraform resolves the latest via "openclaw_ami*" filter.
  ami_name = format(
    "openclaw_ami_%s",
    replace(timestamp(), ":", "-")
  )

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 64
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = format(
      "openclaw_ami_%s",
      replace(timestamp(), ":", "-")
    )
  }
}


# ================================================================================
# SECTION: Build Provisioners
# ================================================================================

build {
  sources = ["source.amazon-ebs.openclaw"]

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

  # Remove snap, install SSM agent DEB, install base packages.
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

  # Install cloud CLIs and dev tooling (git, AWS, HashiCorp, az, gcloud, VS Code).
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
