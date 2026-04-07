# ================================================================================
# SECTION: Networking
# ================================================================================

variable "vpc_name" {
  description = "Name tag of the VPC created by 01-core"
  type        = string
  default     = "clawd-vpc"
}

variable "subnet_name" {
  description = "Name tag of the subnet to place the OpenClaw host in"
  type        = string
  default     = "pub-subnet-1"
}


# ================================================================================
# SECTION: Instance
# ================================================================================

variable "instance_type" {
  description = "EC2 instance type for the OpenClaw host"
  type        = string
  default     = "t3.xlarge"
}

variable "bedrock_model_id" {
  description = "Bedrock Claude Sonnet model ID"
  type        = string
  default     = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "haiku_model_id" {
  description = "Bedrock Claude Haiku model ID"
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "nova_pro_model_id" {
  description = "Bedrock Amazon Nova Pro model ID"
  type        = string
  default     = "us.amazon.nova-pro-v1:0"
}

variable "nova_lite_model_id" {
  description = "Bedrock Amazon Nova Lite model ID"
  type        = string
  default     = "us.amazon.nova-lite-v1:0"
}
