#!/usr/bin/env python3
"""Probe which Vertex AI Gemini models actually answer, and how fast.

Why this exists
    gemini-config.sh lists the models LiteLLM will serve to OpenClaw, and
    check_env.sh verifies each one answers before a deploy starts. Neither
    answers the question you actually have when choosing what goes in that
    list: which models will this project's service account serve today, in
    this location, and what do they cost you in latency?

    Model Garden availability is not uniform. A model id can be perfectly
    valid, be listed by the publisher API, and still return 404 or 403 for a
    given project and location -- because it was never enabled, because the
    service account lacks aiplatform.user, or because that model is simply not
    offered in that location. As with the OCI probe this is modelled on, the
    only reliable test is to make the call.

    So this makes the call, against the same REST path LiteLLM's vertex_ai
    provider uses, and reports what answers and how quickly.

Usage
    python3 probe_vertex.py                     # probe the known Gemini models
    python3 probe_vertex.py flash               # only ids matching a filter
    python3 probe_vertex.py --tokens 800        # realistic generation length
    python3 probe_vertex.py --location us-central1
    python3 probe_vertex.py --check gemini-3.5-flash

    --check verifies one exact id and communicates through the exit code, so a
    shell pre-flight can gate a deploy on it -- the same contract
    probe_genai.py offers in the OCI project.

Requirements
    gcloud, jq, and credentials.json in this directory -- the same three things
    check_env.sh already needs. Deliberately NO Python dependencies: LiteLLM
    reaches Vertex through google-cloud-aiplatform, but that SDK is a POST to
    the endpoint below, and requiring it here would mean the venv dance the OCI
    probe has to do just to run a liveness check.
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CREDENTIALS = os.path.join(HERE, "credentials.json")

API_ROOT = "https://aiplatform.googleapis.com/v1"
API_ROOT_BETA = "https://aiplatform.googleapis.com/v1beta1"

# Fallback candidates, used only when the publisher API will not enumerate.
# This list WILL age -- it is a floor, not a catalog. Discovery is attempted
# first precisely so that a newly released model shows up without editing it.
KNOWN_GEMINI = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-2.5-pro",
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
]


# ==============================================================================
# Environment -- project, token, arguments
# ==============================================================================

def project_id():
    """Read the project id out of credentials.json.

    Matches how check_env.sh resolves it, so the probe cannot disagree with the
    deploy about which project it is talking to.

    Returns:
        The project_id string.

    Raises:
        SystemExit: if credentials.json is missing or has no project_id.
    """
    if not os.path.isfile(CREDENTIALS):
        sys.exit("ERROR: credentials.json not found at %s" % CREDENTIALS)
    with open(CREDENTIALS, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    pid = data.get("project_id")
    if not pid:
        sys.exit("ERROR: credentials.json has no project_id")
    return pid


def access_token():
    """Return a bearer token from the active gcloud account.

    Shelling out to gcloud rather than signing a JWT here keeps this script
    dependency-free and means it authenticates as whatever check_env.sh
    activated, so a permissions result here is the permissions result the
    deploy will get.

    Returns:
        The access token string.

    Raises:
        SystemExit: if gcloud is missing or has no active credentials.
    """
    try:
        out = subprocess.run(
            ["gcloud", "auth", "print-access-token", "--quiet"],
            capture_output=True, text=True, check=True,
        )
    except FileNotFoundError:
        sys.exit("ERROR: gcloud not found in PATH.")
    except subprocess.CalledProcessError as exc:
        sys.exit(
            "ERROR: gcloud could not mint a token.\n"
            "  %s\n"
            "  Activate the service account first:\n"
            "    gcloud auth activate-service-account "
            "--key-file=credentials.json" % exc.stderr.strip()
        )
    return out.stdout.strip()


def post_json(url, token, payload, timeout=120):
    """POST JSON and return (status, parsed_body_or_text, elapsed_seconds)."""
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Authorization", "Bearer %s" % token)
    req.add_header("Content-Type", "application/json")

    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "replace")
            return resp.status, json.loads(raw), time.perf_counter() - t0
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(raw), time.perf_counter() - t0
        except ValueError:
            return exc.code, raw, time.perf_counter() - t0
    except Exception as exc:                       # timeouts, DNS, TLS
        return 0, "%s: %s" % (type(exc).__name__, exc), time.perf_counter() - t0


def get_json(url, token, timeout=30):
    """GET JSON and return the parsed body, or None on any failure."""
    req = urllib.request.Request(url)
    req.add_header("Authorization", "Bearer %s" % token)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", "replace"))
    except Exception:
        return None


# ==============================================================================
# Discovery
# ==============================================================================

def discover(token, filters):
    """List Gemini publisher models, falling back to a hardcoded set.

    ListPublisherModels is not guaranteed to be callable with every credential,
    and its shape has moved between API versions. A probe that dies when
    discovery fails would be less useful than one that falls back and says so,
    so a failure here is reported and then ignored.

    Args:
        token: Bearer token.
        filters: Lowercased substrings; a model is kept if any matches.

    Returns:
        Tuple of (model_ids, source_label).
    """
    url = ("%s/publishers/google/models?pageSize=200" % API_ROOT_BETA)
    data = get_json(url, token)

    ids = []
    if isinstance(data, dict):
        for m in data.get("publisherModels", []):
            # "publishers/google/models/gemini-2.5-flash@default"
            name = (m.get("name") or "").split("/")[-1].split("@")[0]
            if not name.startswith("gemini"):
                continue
            # Embedding and vision-only entries cannot serve generateContent.
            if "embedding" in name or "imagen" in name:
                continue
            ids.append(name)

    source = "publisher API"
    if not ids:
        ids = list(KNOWN_GEMINI)
        source = "built-in list (publisher API returned nothing usable)"

    ids = sorted(set(ids))
    if filters:
        ids = [i for i in ids if any(f in i.lower() for f in filters)]
    return ids, source


# ==============================================================================
# Probe
# ==============================================================================

def probe(token, pid, location, model_id, prompt, max_tokens):
    """Make one real generateContent call.

    Returns:
        Dict with status, elapsed, and -- on success -- the token counts Vertex
        reports back, which is what makes the timing interpretable.
    """
    url = ("%s/projects/%s/locations/%s/publishers/google/models/"
           "%s:generateContent" % (API_ROOT, pid, location, model_id))
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        # temperature 0 keeps the timing comparable between runs; it is not
        # what OpenClaw sends, but a slow model here is slow for the same
        # reason it would be slow in production.
        "generationConfig": {"temperature": 0, "maxOutputTokens": max_tokens},
    }
    status, body, elapsed = post_json(url, token, payload)

    out = {"status": status, "elapsed": elapsed, "error": None,
           "in_tok": None, "out_tok": None, "think_tok": None}

    if status == 200 and isinstance(body, dict):
        usage = body.get("usageMetadata", {})
        out["in_tok"] = usage.get("promptTokenCount")
        out["out_tok"] = usage.get("candidatesTokenCount")
        # 2.5 models reason before answering and bill those tokens separately.
        # They are usually the reason a "Say OK" probe takes seconds.
        out["think_tok"] = usage.get("thoughtsTokenCount")
        return out

    if isinstance(body, dict):
        out["error"] = (body.get("error", {}).get("message")
                        or json.dumps(body))[:70]
    else:
        out["error"] = str(body)[:70]
    return out


def main():
    args = sys.argv[1:]

    # Must match vertex_location in the LiteLLM config that startup.sh
    # renders (VERTEX_LOCATION in gemini-config.sh). Probing a different
    # location answers a question this project never asks.
    location = "global"
    if "--location" in args:
        i = args.index("--location")
        try:
            location = args[i + 1]
        except IndexError:
            sys.exit("ERROR: --location needs a value, e.g. --location "
                     "us-central1")
        del args[i:i + 2]

    # Small by default: --check runs as a pre-flight and a liveness test has no
    # reason to generate real output.
    max_tokens = 16
    prompt = "Reply with OK."
    if "--tokens" in args:
        i = args.index("--tokens")
        try:
            max_tokens = int(args[i + 1])
        except (IndexError, ValueError):
            sys.exit("ERROR: --tokens needs a number, e.g. --tokens 800")
        if max_tokens > 50:
            # A one-word prompt with a big cap just stops early; give it
            # something it will keep writing about so the timing means
            # something.
            prompt = ("Write a short paragraph explaining what a resume is, "
                      "in plain language.")
        del args[i:i + 2]

    check_mode = len(args) >= 2 and args[0] == "--check"
    check_name = args[1] if check_mode else None
    filters = [] if check_mode else [a.lower() for a in args]

    pid = project_id()
    token = access_token()

    if check_mode:
        r = probe(token, pid, location, check_name, prompt, max_tokens)
        if r["status"] == 200:
            print("OK: %s answers in %s (%.2fs)"
                  % (check_name, location, r["elapsed"]))
            return 0
        print("FAIL: %s -> HTTP %s in %s -- %s"
              % (check_name, r["status"], location, r["error"]))
        return 1

    print("project    : %s" % pid)
    print("location   : %s" % location)
    print("max_tokens : %d" % max_tokens)

    ids, source = discover(token, filters)
    print("discovery  : %s" % source)
    print("filters    : %s\n"
          % (filters or "(none -- probing every Gemini model found)"))

    if not ids:
        print("No Gemini models matched.")
        return 1

    print("%d model(s) to probe\n" % len(ids))

    # The first call carries TLS and connection setup, so it reads high. Absorb
    # it against the first model rather than unfairly penalising whichever id
    # happens to sort first. Only worth the extra round trip when ranking.
    if len(ids) > 1:
        t0 = time.perf_counter()
        probe(token, pid, location, ids[0], "Hi", 1)
        print("  warm-up  %7.2fs  (discarded)\n" % (time.perf_counter() - t0))

    working = []
    for mid in ids:
        r = probe(token, pid, location, mid, prompt, max_tokens)
        label = "%-30s" % mid
        if r["status"] == 200:
            think = ("  think %4d" % r["think_tok"]) if r["think_tok"] else ""
            print("  OK    %s %7.2fs  in %4s  out %4s%s"
                  % (label, r["elapsed"], r["in_tok"], r["out_tok"], think))
            working.append((mid, r))
        else:
            print("  %-5s %s %7.2fs  %s"
                  % (r["status"], label, r["elapsed"], r["error"]))

    # ==========================================================================
    # Result -- fastest first
    # ==========================================================================
    print()
    if not working:
        print("No Gemini model answered in %s." % location)
        print("Check that the service account has roles/aiplatform.user and")
        print("that the Vertex AI API is enabled on %s." % pid)
        return 1

    working.sort(key=lambda pair: pair[1]["elapsed"])
    print("Answered in %s (%d max_tokens, fastest first):" % (location,
                                                              max_tokens))
    for mid, r in working:
        out_tok = r["out_tok"] or 0
        rate = ("  %6.1f tok/s" % (out_tok / r["elapsed"])
                if out_tok and r["elapsed"] > 0 else "")
        print("  %7.2fs  %-30s%s" % (r["elapsed"], mid, rate))

    print()
    print("Add one of these to GEMINI_MODELS in gemini-config.sh.")
    print("Timings RANK models against each other -- they are not a throughput")
    print("measure. A 16-token reply is mostly connection setup plus time to")
    print("first token; re-run with --tokens 800 for something closer to the")
    print("length an agent turn actually generates.")
    if any(r["think_tok"] for _, r in working):
        print()
        print("A 'think' column means the model spent reasoning tokens before")
        print("answering. On 2.5 models that is usually why a trivial prompt")
        print("takes seconds, and you pay for those tokens.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
