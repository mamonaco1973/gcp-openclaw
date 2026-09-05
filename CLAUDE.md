# CLAUDE.md — gcp-openclaw

## Project Overview

Terraform + Packer project that deploys a GCE instance running **OpenClaw**
(an AI coding agent) backed by a **LiteLLM proxy** pointed at **Vertex AI**
Gemini models. Users RDP into an LXQt desktop and open the OpenClaw web UI at
`http://localhost:18789` in Chrome. The instance authenticates to Vertex AI and
Secret Manager through its service account — no keys on disk.

## Architecture

```
01-core/          VPC + subnet + Secret Manager secrets
02-packer/        Packer build: Ubuntu 24.04 → openclaw-images family
  scripts/        01-packages through 14-apache
  files/          litellm.service, openclaw-gateway.service, xvfb.service
03-openclaw/      GCE instance + firewall rule + credentials secret
  scripts/
    startup.sh    Boot: set password from secret, render litellm config,
                  register models with OpenClaw, start systemd services
gemini-config.sh  Single source of truth for the model list
probe_vertex.py   Reports which Vertex models this project can actually call
```

### Deployment Order

1. `01-core` — VPC, subnet, SMTP secret
2. `02-packer` — Packer builds an image in the `openclaw-images` family
3. `03-openclaw` — GCE instance, firewall rule, credentials secret

### Key Resources

| Resource | Value |
|---|---|
| Region / zone | `us-east4` / `us-east4-b` |
| VPC / subnet | `openclaw-vpc` / `openclaw-subnet` (`10.0.0.0/24`) |
| Instance name | `openclaw-host` |
| Machine type | `e2-standard-4` (variable), 128 GB SSD root disk |
| Image family | `openclaw-images` |
| LiteLLM port | `4000` (loopback) |
| LiteLLM master key | `sk-openclaw` |
| OpenClaw gateway port | `18789` (loopback only) |
| Vertex models | From `gemini-config.sh`; location `global` |
| Linux user | `openclaw` (sudo, NOPASSWD) |
| Password source | Secret Manager `openclaw-credentials` |
| SMTP source | Secret Manager `openclaw-smtp` |

## Common Commands

```bash
# Validate environment: CLI tools, gcloud auth, APIs, and every model
# in gemini-config.sh answering on Vertex
./check_env.sh

# Deploy everything (01-core → 02-packer → 03-openclaw → validate)
./apply.sh

# Tear down (03-openclaw → delete images → 01-core)
./destroy.sh

# Print connection details, including the password
./validate.sh

# See which Vertex models this project can actually call, ranked by latency
./probe_vertex.py
```

### Connecting to the Instance

RDP straight to the instance's external IP on 3389 — `validate.sh` prints the
IP, username, and password. There is no bastion and no tunnel.

## Model Configuration

`gemini-config.sh` is the single source of truth. It defines a `GEMINI_MODELS`
array of `alias|vertex-model-id|display name`, plus `GEMINI_PRIMARY` and
`VERTEX_LOCATION`, and exports them to Terraform as `TF_VAR_models`,
`TF_VAR_primary_alias`, and `TF_VAR_vertex_location`.

Everything derives from that one array: the LiteLLM `model_list`, the OpenClaw
model picker, and the `check_env.sh` pre-flight. Any number of entries from 1
upward renders correctly.

**Why aliases.** The alias is what LiteLLM routes on and what OpenClaw stores
as the model ID. Vertex model IDs expire on a published schedule; the alias
does not, so bumping a model does not repoint existing agents.

**Why the probe.** A Gemini ID can be real, be listed by the publisher API, and
still return 404 or 403 for a given project and location — never enabled,
missing `aiplatform.user`, or not offered there. The only reliable test is to
make the call. `check_env.sh` probes every ID before any resource is created.

Latency ranks models against each other. It says nothing about whether a model
can drive a multi-step tool-calling turn — verify that in the UI before
trusting a new primary.

## What Packer (02-packer) Does

Builds an image in the `openclaw-images` family from Ubuntu 24.04:

| Script | What it installs |
|---|---|
| `01-packages.sh` | Removes snap, installs base packages |
| `02-desktop.sh` | LXQt desktop environment |
| `03-xrdp.sh` | XRDP + LXQt session config |
| `04-chrome.sh` | Google Chrome Stable |
| `05-tools.sh` | Git, AWS CLI v2, Terraform, Packer, Azure CLI, gcloud, VS Code |
| `06-user.sh` | `openclaw` Linux user with passwordless sudo |
| `07-node.sh` | Node.js 22, OpenClaw, desktop launcher |
| `08-litellm.sh` | Python venv at `/opt/litellm-venv`, `litellm[proxy]` |
| `11-python-tools.sh` | Pinned Python packages and system utilities |
| `12-onlyoffice.sh` | OnlyOffice Desktop Editors |
| `13-gcp-tools.sh` | `gcp-infra-report`, `send-infra-report` |
| `14-apache.sh` | Apache2 serving world-writable `/var/www/html` on loopback |
| `09-openclaw-init.sh` | Stamps gateway config; writes `HEARTBEAT.md`/`SYSTEM.md` |
| `10-services.sh` | Installs and enables the systemd units |

Note the provisioner order is not the filename order: `09` and `10` run last,
because the gateway must be stamped after everything it advertises exists.

## What startup.sh Does

Runs at first boot from instance metadata (NOT baked into the image, so a
`terraform apply` plus a reboot is enough to change it):

1. Reads `openclaw-credentials` from Secret Manager and sets the `openclaw`
   password
2. Renders `/opt/openclaw/litellm-config.yaml`, one `model_list` entry per
   model in `gemini-config.sh`
3. Reads `openclaw-smtp` and configures msmtp plus the `gcp-mail` wrapper
4. Starts `litellm.service` and `openclaw-gateway.service`
5. On first boot only (guarded by `/etc/openclaw-configured`): registers the
   LiteLLM provider and every model with OpenClaw, sets the primary, adds the
   exec allowlist, and restarts the gateway

### Gotcha: `$$` in the template

`startup.sh` is rendered through `templatefile`, which treats `$$` as an escape
**only when a `{` follows it**. So `$${PATH}` correctly becomes `${PATH}`, but
`$$@` survives into the rendered script and bash reads it as `$$` (the PID)
followed by a literal `@`. Positional parameters must be written `"$@"`.

This shipped once: every `openclaw` call became `openclaw <pid>@`, model
registration failed, and the UI showed the first-run "connect a model" page.

## Authentication

There is no dedicated service account resource. `03-openclaw/main.tf` reads
`../credentials.json` and uses its `client_email` as the instance service
account, attached with the `cloud-platform` scope. The same identity is granted
`roles/secretmanager.secretAccessor` on both secrets.

## Networking Design

- `openclaw-vpc` — custom mode, one subnet `10.0.0.0/24` in `us-east4`
- `openclaw-allow-rdp` — 3389 inbound from `0.0.0.0/0`, applied by network tag
- The instance has an ephemeral external IP; RDP connects to it directly
- **Cloud Router and Cloud NAT are commented out** in `01-core/networking.tf`.
  Cloud NAT only carries egress for instances with no external IP, so it was
  billing without ever passing a packet. Uncomment both if the external IP is
  ever dropped in favour of IAP-tunnelled RDP.
- Apache listens on 80 but no firewall rule opens it — deliberately loopback
  only, for showing pages on the desktop

## Password Format

Generated by Terraform in `03-openclaw/accounts.tf`:

```
<word>-<6-digit-number>   e.g. "rocket-482910"
```

Stored in Secret Manager as `{"username": "openclaw", "password": "..."}`.
