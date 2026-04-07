# ================================================================================
# SECTION: VPC Naming
# ================================================================================

# Name assigned to the VPC resource created for this environment.
variable "vpc_name" {
  description = "Name for the VPC resource"
  type        = string
  default     = "clawd-vpc"
}

variable "ses_email" {
  description = "Email address to verify in SES for outbound sending (a verification email will be sent here)"
  type        = string
}
