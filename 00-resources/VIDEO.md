#GCP #AIAgent #OpenClaw #LiteLLM #VertexAI #Terraform #Packer #Gemini

*Run an AI Agent on GCP in Minutes (OpenClaw + Vertex AI)*

Deploy a fully autonomous AI agent workstation on Google Cloud Platform using Terraform, Packer, OpenClaw, and Vertex AI. The agent runs on an Ubuntu GCE instance with an LXQt desktop, backed by Gemini 2.5 Flash and Gemini 2.5 Pro routed through a LiteLLM proxy.

In this project we give the agent three plain English instructions and watch it generate a GCP infrastructure snapshot, send it as a styled HTML email, and schedule itself as a nightly recurring task — no scripts written by hand, no credentials managed, no additional configuration.

WHAT YOU'LL LEARN
• Deploying an AI agent workstation on GCP with Terraform and Packer
• Routing Vertex AI Gemini models through LiteLLM for OpenAI-compatible access
• Giving an AI agent access to GCP APIs through a VM service account
• Configuring outbound email with msmtp and a pre-configured gcp-mail wrapper
• Driving real automation with plain English instructions

INFRASTRUCTURE DEPLOYED
• VPC with subnet and Cloud NAT for egress (us-east4)
• Ubuntu 24.04 GCE instance (e2-standard-4) with LXQt desktop and XRDP
• Packer-built image with OpenClaw, LiteLLM, Chrome, VS Code, and developer tooling
• LiteLLM proxy configured for Gemini 2.5 Flash and Gemini 2.5 Pro via Vertex AI
• VM service account with cloud-platform scope for credential-free GCP API access
• Secret Manager secrets for desktop password and SMTP credentials
• gcp-infra-report and send-infra-report helper scripts baked into the image

GitHub
https://github.com/mamonaco1973/gcp-openclaw

README
https://github.com/mamonaco1973/gcp-openclaw/blob/main/README.md

TIMESTAMPS
00:00 Introduction
00:22 Architecture
00:51 Build the Code
01:07 Build Results
01:39 Demo
