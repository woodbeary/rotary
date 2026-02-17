# TXT CLAW CLI

The CLI scaffolds a working setup and verifies your API key.

## Install/run (no global install)

```bash
pnpm dlx txtclaw@latest init
```

## Doctor (verify credentials)

```bash
# Recommended (production):
export TXTCLAW_API_BASE_URL="https://api.txtclaw.com"
#
# Preview (if you're testing / staging):
# export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"

pnpm dlx txtclaw@latest doctor
```

## Environment

- `TXTCLAW_API_BASE_URL` (optional, defaults to `https://api.txtclaw.com`; use preview Worker URL for staging)
- `TXTCLAW_API_KEY` (required)
