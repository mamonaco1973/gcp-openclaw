#!/usr/bin/env bash
# ==============================================================================
# gemini-config.sh
# ==============================================================================
#
# Single source of truth for the Vertex AI models LiteLLM serves to OpenClaw.
# Sourced by apply.sh and check_env.sh so every script agrees on one list, and
# exported into Terraform so the deploy cannot drift from what was validated.
#
# ------------------------------------------------------------------------------
# Why a list and not two variables
# ------------------------------------------------------------------------------
# This started as primary_model/secondary_model, which fixed the count at two
# and put the display names in a third place (startup.sh) where they promptly
# went stale -- the picker still said "Gemini 2.5" after the ids moved on.
# Everything now derives from the array below: the LiteLLM model_list, the
# OpenClaw model picker, and the pre-flight checks. Any number of entries from
# 1 upward renders correctly.
#
# ------------------------------------------------------------------------------
# Which models, and why
# ------------------------------------------------------------------------------
# gemini-2.5-flash retires on Vertex 2026-10-16 and the rest of the 2.5 family
# follows it. Moving before the deadline beats moving during an outage. The
# same change was made in gcp-resume-app.
#
# Note there is no stable Pro in 3.x -- only gemini-3.1-pro-preview.
#
# The primary is NOT simply the newest model. Latency ranks models against each
# other but says nothing about whether one can drive the Exec tool through a
# multi-step agent turn, and the newest Flash could not: see the exclusion
# note below. Always verify tool calling in the UI before changing the primary.
#
# ------------------------------------------------------------------------------
# Model ids are NOT guaranteed to resolve
# ------------------------------------------------------------------------------
# A Gemini id can be real, be listed by the publisher API, and still 404 or 403
# for a given project and location -- never enabled, missing aiplatform.user,
# or simply not offered there. The only reliable test is to make the call, so
# check_env.sh probes every id in this list before a deploy starts.
#
# To see what your project can actually serve, and how fast:
#     ./probe_vertex.py
#     ./probe_vertex.py --check gemini-3.5-flash
#
# ------------------------------------------------------------------------------
# Format
# ------------------------------------------------------------------------------
#     "<alias>|<vertex-model-id>|<display name>"
#
#   alias    what LiteLLM routes on and what OpenClaw stores as the model id.
#            Changing it repoints agents, so keep it stable across id bumps --
#            that is the entire point of having an alias.
#   model    the Vertex id. This is the part that expires.
#   display  what a human sees in the OpenClaw model picker.
# ==============================================================================

# Aliases name the ROLE, not the model tier. Tiers move -- there is currently
# no stable Pro in the 3.x line at all -- so an alias like "gemini-pro" would
# be a lie in the picker the moment it pointed at a Flash model.
#
# Chosen from a probe run 2026-09-05. Excluded deliberately:
#   *-image           image generation, not chat
#   *-transcribe-*    audio
#   *-preview         can vanish with no retirement notice (this is why the
#                     only 3.x Pro, gemini-3.1-pro-preview, is not here)
#   gemini-2.5-*      retiring from 2026-10-16
#   gemini-3.8-flash  EXCLUDED. It ignores reasoning_effort: disable and
#                     thinks anyway, so it still emits the thought_signature
#                     that LiteLLM corrupts -- every multi-turn tool
#                     conversation dies on the second tool call. 3.5 and 3.1
#                     honour the setting and work. Verified 2026-09-06.
GEMINI_MODELS=(
  "gemini-primary|gemini-3.5-flash|Gemini 3.5 Flash (Vertex)"
  "gemini-fast|gemini-3.5-flash-lite|Gemini 3.5 Flash-Lite (Vertex)"
  "gemini-lite|gemini-3.1-flash-lite|Gemini 3.1 Flash-Lite (Vertex)"
)

# Alias agents default to. Must be one of the aliases above; check_env.sh and
# Terraform both reject a primary that is not in the list, because it yields an
# OpenClaw that starts fine and cannot run an agent.
GEMINI_PRIMARY="gemini-primary"

# Vertex location. Must match vertex_location in the LiteLLM config rendered by
# 03-openclaw/scripts/startup.sh -- a model available in one location is not
# necessarily available in another, so validating against a different one
# proves nothing.
#
# "global" rather than a region: it is what the models above were probed
# against, and what gcp-resume-app already runs on.
export VERTEX_LOCATION="${VERTEX_LOCATION:-global}"


# ==============================================================================
# Helpers
# ==============================================================================

# JSON array of model objects, shaped for TF_VAR_models.
gemini_models_json() {
  local entry alias model display
  for entry in "${GEMINI_MODELS[@]}"; do
    IFS='|' read -r alias model display <<< "${entry}"
    jq -n \
      --arg alias   "${alias}" \
      --arg model   "${model}" \
      --arg display "${display}" \
      '{alias: $alias, model: $model, display: $display}'
  done | jq -s '.'
}

# Vertex model ids, one per line -- what check_env.sh probes.
gemini_model_ids() {
  local entry
  for entry in "${GEMINI_MODELS[@]}"; do
    printf '%s\n' "${entry}" | cut -d'|' -f2
  done
}

# Aliases, one per line.
gemini_model_aliases() {
  local entry
  for entry in "${GEMINI_MODELS[@]}"; do
    printf '%s\n' "${entry}" | cut -d'|' -f1
  done
}

# Resolve an alias to its Vertex id; non-zero if the alias is unknown.
gemini_model_for_alias() {
  local want="$1" entry alias model
  for entry in "${GEMINI_MODELS[@]}"; do
    IFS='|' read -r alias model _ <<< "${entry}"
    if [ "${alias}" = "${want}" ]; then
      printf '%s' "${model}"
      return 0
    fi
  done
  return 1
}

# Hand the list to Terraform. Called by apply.sh before the 03-openclaw apply.
gemini_export_tf_vars() {
  TF_VAR_models="$(gemini_models_json)"
  TF_VAR_primary_alias="${GEMINI_PRIMARY}"
  TF_VAR_vertex_location="${VERTEX_LOCATION}"
  export TF_VAR_models TF_VAR_primary_alias TF_VAR_vertex_location
}
