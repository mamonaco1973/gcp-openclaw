# configure.md — Post-Deploy OpenClaw Setup

Steps to complete after `./apply.sh` finishes. Allow ~2 minutes for
`startup.sh` to set the password, render the LiteLLM config, and register the
models with OpenClaw.

---

## 1. Get the Connection Details

`validate.sh` prints the instance name, the external IP, the username, and the
password:

```bash
./validate.sh
```

To fetch the password on its own later:

```bash
gcloud secrets versions access latest \
  --secret="openclaw-credentials" | jq -r '.password'
```

---

## 2. RDP Into the Instance

Connect your RDP client straight to the external IP on port `3389` — there is
no bastion and no tunnel.

```
Host:     <external-ip>:3389
Username: openclaw
Password: from step 1
```

---

## 3. Verify Services Are Running

From the RDP terminal:

```bash
systemctl status litellm
systemctl status openclaw-gateway
```

Both should show `active (running)`. To check logs:

```bash
journalctl -u litellm -n 50
journalctl -u openclaw-gateway -n 50
```

Check the startup script completed — this is a GCE metadata startup script, so
it logs to the journal rather than a file:

```bash
journalctl -u google-startup-scripts --no-pager | tail -40
```

---

## 4. Open OpenClaw in Chrome

Double-click the **OpenClaw** desktop icon. It waits for the gateway to answer,
then opens Chrome at:

```
http://127.0.0.1:18789/chat/main
```

The launcher deliberately does not use `openclaw dashboard`: from 2026.8.2 that
mints a one-time bootstrap token in the URL fragment, and re-pairing on page
load races the Control UI's WebSocket connect, so the tab lands on the manual
connect form and only works after a refresh.

---

## 5. Verify the Models Registered

The model picker in the OpenClaw toolbar should list every model from
`gemini-config.sh`. If it instead shows a "Connect a verified AI model" page,
registration failed — see Troubleshooting below.

From the terminal, confirm each layer separately:

```bash
# LiteLLM is serving the aliases
curl -s -H 'Authorization: Bearer sk-openclaw' \
  http://localhost:4000/v1/models | jq -r '.data[].id'

# OpenClaw has them registered
sudo -u openclaw env HOME=/home/openclaw \
  openclaw config get models.providers.litellm
```

---

## 6. Verify Tool Calling

Model latency says nothing about whether a model can drive a multi-step turn.
Before trusting the primary, give it something that requires an actual tool
call — the Breakout prompt in the README is a good test, because it fails
visibly if the model narrates the call instead of making it.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Connect a verified AI model" page | Model registration failed at boot. Check `journalctl -u google-startup-scripts \| grep -i openclaw` |
| `openclaw-gateway` fails to start | Check litellm is up first: `systemctl status litellm` |
| LiteLLM 401 / auth error | Verify master key: `grep master_key /opt/openclaw/litellm-config.yaml` |
| Vertex 403 / permission error | The instance service account needs `roles/aiplatform.user` on the project |
| Vertex 404 on a model | The ID is not served for this project and location. Run `./probe_vertex.py` and update `gemini-config.sh` |
| Model picker is empty | `sudo -u openclaw env HOME=/home/openclaw openclaw config get models.providers.litellm` — if unset, re-run the registration block |
| Change the models | Edit `gemini-config.sh`, re-apply `03-openclaw`, then reboot the instance |
| Agent narrates `[exec ...]` instead of running it | The model is not tool-calling reliably. Switch `GEMINI_PRIMARY` to another alias |
| "LLM request failed: provider rejected the request schema or tool payload" after the first tool call succeeds | `thought_signature` corruption — see below |
| Chrome shows an "unsupported flag" banner | The AppArmor userns sysctl did not apply: `sysctl kernel.apparmor_restrict_unprivileged_userns` should be `0` |
| Agent cannot write to `/var/www/html` | `stat -c '%a' /var/www/html` should be `777` |

### Gemini 3 thought signatures

The agent completes one tool call, then the next turn dies with *"provider
rejected the request schema or tool payload"*. The real error is in the LiteLLM
journal:

```
Invalid value at 'contents[5].parts[1].thought_signature' (TYPE_BYTES),
Base64 decoding failed for "AY89a18FPv7xX9mLUNs8iOTLhUwPPp_b6be96db03"
```

Gemini 3 attaches a signature to tool-call parts that must be echoed back
unchanged. OpenClaw uses the Responses API, and that bridge mangles it into a
shortened tool-call ID — always 30 characters plus `_<10 hex>`.

The deploy sets `reasoning_effort: disable` on every model to prevent this. If
you hit it anyway, confirm the setting survived:

```bash
grep -c "reasoning_effort: disable" /opt/openclaw/litellm-config.yaml
systemctl restart litellm
```

Then start a new conversation — an existing one has the bad signature in its
history and will keep failing regardless of the fix.

### Changing the model list on a running instance

`startup.sh` is instance metadata, not baked into the image, so the model list
can be changed without a Packer rebuild:

```bash
source ./gemini-config.sh && gemini_export_tf_vars
cd 03-openclaw && terraform apply -auto-approve \
  -var="openclaw_image_name=<current image>" \
  -var="zone=us-east4-b" -var="region=us-east4"
gcloud compute instances reset openclaw-host --zone us-east4-b
```

The registration block is guarded by `/etc/openclaw-configured`. If that file
exists, the reboot will skip it — remove it first to force a re-register.
