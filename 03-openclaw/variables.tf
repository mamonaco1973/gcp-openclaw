# ================================================================================
# SECTION: Networking
# ================================================================================

variable "vpc_name" {
  description = "Name of the VPC created by 01-core"
  type        = string
  default     = "openclaw-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet created by 01-core"
  type        = string
  default     = "openclaw-subnet"
}


# ================================================================================
# SECTION: Instance
# ================================================================================

variable "machine_type" {
  description = "GCE machine type for the OpenClaw host"
  type        = string
  default     = "e2-standard-4"
}

variable "zone" {
  description = "GCP zone for the OpenClaw host"
  type        = string
  default     = "us-east4-b"
}

variable "openclaw_image_name" {
  description = "Name of the Packer-built openclaw GCP image (resolved by apply.sh)"
  type        = string
}


# ================================================================================
# SECTION: AI Models (Vertex AI)
# ================================================================================

variable "primary_model" {
  description = "Vertex AI model ID for the primary model"
  type        = string
  default     = "gemini-2.0-flash-001"
}

variable "secondary_model" {
  description = "Vertex AI model ID for the secondary model"
  type        = string
  default     = "gemini-2.0-pro-001"
}
