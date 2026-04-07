# ================================================================================
# SECTION: VPC Naming
# ================================================================================

variable "vpc_name" {
  description = "Name for the VPC resource"
  type        = string
  default     = "openclaw-vpc"
}

variable "subnet_name" {
  description = "Name for the subnet resource"
  type        = string
  default     = "openclaw-subnet"
}


# ================================================================================
# SECTION: SMTP
# ================================================================================

variable "smtp_host" {
  description = "SMTP server hostname"
  type        = string
  default     = "smtp.example.com"
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = string
  default     = "587"
}

variable "smtp_username" {
  description = "SMTP authentication username"
  type        = string
  default     = "user@example.com"
}

variable "smtp_password" {
  description = "SMTP authentication password"
  type        = string
  default     = "changeme"
  sensitive   = true
}

variable "smtp_from" {
  description = "From address for outbound email"
  type        = string
  default     = "user@example.com"
}
