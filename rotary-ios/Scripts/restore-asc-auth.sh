#!/usr/bin/env bash

set -euo pipefail

required_vars=(
  ASC_KEY_ID
  ASC_ISSUER_ID
  ASC_PRIVATE_KEY_PATH
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

profile_name="${ASC_PROFILE_NAME:-rotary-appstore}"

asc auth login \
  --name "${profile_name}" \
  --key-id "${ASC_KEY_ID}" \
  --issuer-id "${ASC_ISSUER_ID}" \
  --private-key "${ASC_PRIVATE_KEY_PATH}"

asc auth status
