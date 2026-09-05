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

variable "region" {
  description = "GCP region for the OpenClaw host"
  type        = string
  default     = "us-east4"
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

# Populated from gemini-config.sh via TF_VAR_models. The defaults here are a
# fallback for a bare `terraform apply` and are kept in step with that file --
# apply.sh always exports over them.
variable "models" {
  description = "Vertex AI models LiteLLM serves to OpenClaw (from gemini-config.sh)"

  type = list(object({
    # What LiteLLM routes on and what OpenClaw stores as the model id. Stable
    # across Vertex id changes, which is the point of having an alias.
    alias = string

    # The Vertex model id. This is the part that expires.
    model = string

    # Shown in the OpenClaw model picker.
    display = string
  }))

  default = [
    {
      alias   = "gemini-primary"
      model   = "gemini-3.8-flash"
      display = "Gemini 3.8 Flash (Vertex)"
    },
    {
      alias   = "gemini-fast"
      model   = "gemini-3.5-flash"
      display = "Gemini 3.5 Flash (Vertex)"
    },
    {
      alias   = "gemini-lite"
      model   = "gemini-3.1-flash-lite"
      display = "Gemini 3.1 Flash-Lite (Vertex)"
    },
  ]

  validation {
    condition     = length(var.models) > 0
    error_message = "At least one model must be defined in gemini-config.sh."
  }

  validation {
    condition     = length(distinct([for m in var.models : m.alias])) == length(var.models)
    error_message = "Model aliases must be unique - LiteLLM routes on the alias."
  }
}

variable "primary_alias" {
  description = "Alias from var.models that agents default to"
  type        = string
  default     = "gemini-primary"

  # Cross-variable validation (Terraform >= 1.9). A primary that is not in the
  # list produces an OpenClaw that starts fine and cannot run an agent, which
  # is a far worse failure than a plan-time error.
  validation {
    condition     = contains([for m in var.models : m.alias], var.primary_alias)
    error_message = "primary_alias must be one of the aliases in var.models."
  }
}

variable "vertex_location" {
  description = "Vertex AI location LiteLLM calls (must match what check_env.sh probed)"
  type        = string
  default     = "global"
}
