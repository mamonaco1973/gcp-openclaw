# Video Script — AI Agent Workstation on GCP with OpenClaw

---

## Introduction

[ Screen recording of OpenClaw running the infrastructure report — agent executing gcloud commands, email arriving in inbox ]

"Do you want an AI agent that can automate cloud tasks directly inside your GCP environment?"

[ Architecture diagram — walk through it left to right: user, GCE instance, Vertex AI ]

"In this project we deploy an AI agent workstation on GCP using Terraform, Packer, OpenClaw, and Vertex AI."

[ OpenClaw UI showing the agent mid-task with terminal output visible ]

"The agent runs on a GCE instance with access to the filesystem, terminal, browser, and GCP APIs — all through the VM service account."

[ Terminal running apply.sh — flying through build steps, ends with connection details ]

"Follow along and in minutes you'll have a fully functional AI agent running in your GCP environment."

---

## Architecture

[ Full diagram ]

"Let's walk through the architecture before we build."

[ Highlight GCE instance ]

"At the center is an Ubuntu GCE instance with a desktop environment — the agent's workstation. You connect over RDP and get a normal desktop with Chrome, VS Code, and a terminal."

[ Highlight OpenClaw gateway ]

"OpenClaw runs on that instance and gives the agent its capabilities — shell execution, filesystem access, browser control, and email."

[ Highlight LiteLLM + Vertex AI ]

"Reasoning goes through LiteLLM, which proxies requests to Vertex AI — Gemini 2.5 Flash for fast tasks, Gemini 2.5 Pro for complex reasoning."

[ Highlight Secret Manager ]

"Credentials and SMTP config are stored in Secret Manager and pulled at boot. No keys on disk, no credentials in code."

[ Highlight SMTP ]

"Outbound email routes through msmtp with a gcp-mail wrapper — from address pre-configured, no flags needed."

[ Full diagram ]

"A workstation on GCP, an AI agent on top of it, wired to Vertex AI and GCP services. Let's build it."

---

## Build Results

[ Terminal — build complete, connection details printed ]

"The build has completed. Now let's look at what was deployed."

[ GCP Console — GCE instance running, public IP visible ]

"The AI agent's workstation is running as a GCE instance."

[ GCP Console — Secret Manager, openclaw-credentials and openclaw-smtp ]

"Two secrets are in Secret Manager — one holds the desktop password, the other holds the SMTP credentials. The instance pulls both at boot."

[ GCP Console — Vertex AI API enabled ]

"Vertex AI is enabled and the VM service account has cloud-platform scope — the agent can call Gemini models with no API keys needed."

[ RDP session connecting — LXQt desktop loads ]

"Connect over RDP and the desktop is ready. Chrome, VS Code, a terminal — everything the agent needs to do real work."

[ Chrome opening to localhost:18789 — OpenClaw UI ]

"OpenClaw is already running. Open Chrome and the agent interface is waiting."

---

## Demo

[ OpenClaw UI — empty prompt box ]

"Let's give the agent its first task. One sentence, plain English."

[ Typing the first prompt ]

"Generate an infrastructure report."

[ Agent running gcp-infra-report — output visible in conversation ]

"The agent runs gcp-infra-report, which queries the GCP APIs and returns a snapshot of every resource in the project — instances, disks, images, firewall rules, secrets, networks, buckets."

[ Typing the second prompt ]

"Email that report to mamonaco1973@gmail.com."

[ Agent running send-infra-report — styled HTML email being built and sent ]

"The agent calls send-infra-report, formats the data as a styled HTML email with proper tables, and sends it through gcp-mail. No additional instructions."

[ Inbox — styled HTML infrastructure report email arrives ]

"There's the report. Every resource section formatted as a proper HTML table, delivered to the inbox."

[ Back to OpenClaw — typing the third prompt ]

"Now let's make it recurring."

[ Typing the third prompt ]

"Schedule that email report to run nightly at midnight."

[ Agent adding crontab entry — cron confirmation visible ]

"The agent registers a cron job. The infrastructure report will land in the inbox every night automatically, no further input needed."

---
