#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${ASC_APP_ID:-}" ]]; then
  printf 'Missing required env var: ASC_APP_ID\n' >&2
  exit 1
fi

group_id="${ASC_GROUP_ID:-}"
project_path="${ROTARY_PROJECT_PATH:-Rotary.xcodeproj}"
scheme="${ROTARY_SCHEME:-Rotary}"
archive_path="${ROTARY_ARCHIVE_PATH:-output/archive/Rotary.xcarchive}"
export_path="${ROTARY_EXPORT_PATH:-output/export}"
export_options="${ROTARY_EXPORT_OPTIONS_PLIST:-ExportOptions.plist}"

asc auth status

asc xcode version bump --project "${project_path}" --scheme "${scheme}" --type build

asc xcode archive \
  --project "${project_path}" \
  --scheme "${scheme}" \
  --configuration Release \
  --archive-path "${archive_path}"

asc xcode export \
  --archive-path "${archive_path}" \
  --export-options-plist "${export_options}" \
  --output-path "${export_path}"

asc builds upload --app "${ASC_APP_ID}" --ipa "${export_path}/Rotary.ipa"
asc builds wait --app "${ASC_APP_ID}" --latest

if [[ -n "${group_id}" ]]; then
  asc builds add-groups \
    --app "${ASC_APP_ID}" \
    --latest \
    --group "${group_id}" \
    --submit \
    --confirm
else
  asc testflight groups list --app "${ASC_APP_ID}"
fi
