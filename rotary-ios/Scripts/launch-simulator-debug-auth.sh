#!/usr/bin/env bash

set -euo pipefail

device_id="${ROTARY_SIM_DEVICE_ID:-booted}"
bundle_id="${ROTARY_BUNDLE_ID:-com.theinterpretingapp.rotaryapp}"

required_vars=(
  ROTARY_DEBUG_EMAIL
  ROTARY_DEBUG_SESSION_TOKEN
)

missing=()
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing+=("${var_name}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required env vars: %s\n' "${missing[*]}" >&2
  exit 1
fi

export SIMCTL_CHILD_ROTARY_DEBUG_EMAIL="${ROTARY_DEBUG_EMAIL}"
export SIMCTL_CHILD_ROTARY_DEBUG_SESSION_TOKEN="${ROTARY_DEBUG_SESSION_TOKEN}"
export SIMCTL_CHILD_ROTARY_DEBUG_CLIENT_ID="${ROTARY_DEBUG_CLIENT_ID:-debug-client}"
export SIMCTL_CHILD_ROTARY_DEBUG_SESSION_ID="${ROTARY_DEBUG_SESSION_ID:-debug-session}"
export SIMCTL_CHILD_ROTARY_DEBUG_DEVICE_TOKEN="${ROTARY_DEBUG_DEVICE_TOKEN:-debug-device}"

if [[ -n "${ROTARY_USE_CACHED_BOOTSTRAP_ONLY:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_USE_CACHED_BOOTSTRAP_ONLY="${ROTARY_USE_CACHED_BOOTSTRAP_ONLY}"
fi

if [[ -n "${ROTARY_DEBUG_SKIP_FIRST_RUN_ONBOARDING:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_SKIP_FIRST_RUN_ONBOARDING="${ROTARY_DEBUG_SKIP_FIRST_RUN_ONBOARDING}"
fi

if [[ -n "${ROTARY_DEBUG_ACTION:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_ACTION="${ROTARY_DEBUG_ACTION}"
fi

if [[ -n "${ROTARY_DEBUG_MODE:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_MODE="${ROTARY_DEBUG_MODE}"
fi

if [[ -n "${ROTARY_DEBUG_TAB:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_TAB="${ROTARY_DEBUG_TAB}"
fi

if [[ -n "${ROTARY_DEBUG_THREAD_ID:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_THREAD_ID="${ROTARY_DEBUG_THREAD_ID}"
fi

if [[ -n "${ROTARY_DEBUG_PROMPT:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_PROMPT="${ROTARY_DEBUG_PROMPT}"
fi

if [[ -n "${ROTARY_DEBUG_AGENT_ID:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_AGENT_ID="${ROTARY_DEBUG_AGENT_ID}"
fi

if [[ -n "${ROTARY_DEBUG_AUTO_APPROVE:-}" ]]; then
  export SIMCTL_CHILD_ROTARY_DEBUG_AUTO_APPROVE="${ROTARY_DEBUG_AUTO_APPROVE}"
fi

xcrun simctl terminate "${device_id}" "${bundle_id}" >/dev/null 2>&1 || true
xcrun simctl launch "${device_id}" "${bundle_id}"
