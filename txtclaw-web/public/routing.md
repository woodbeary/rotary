# TXT CLAW Routing (Hosted Router Lane)

TXT CLAW supports two LLM lanes:

- **Hosted router** (default): TXT CLAW pays the model bill and routes requests.
- **BYOK** (optional): you bring a provider key (see `https://www.txtclaw.com/byok.md`).

This doc describes the hosted router behavior and the `llm` fields you can set on agent creation.

## Hosted Router Defaults

- `llm.mode`: `hosted` (default)
- `llm.tier`: `fast` (default)
- `llm.model`: optional explicit override

## Auto-Router (Primary + Fallback)

When configured, TXT CLAW can try a primary model and fall back to a smarter model on upstream failures.

How it works (conceptually):

- Attempt 1: primary model (fast)
- Attempt 2+: fallback model (smart), if configured

## Create An Agent With Hosted Router

```bash
# Recommended (custom domain):
# export TXTCLAW_API_BASE_URL="https://api.txtclaw.com"
#
# Preview base URL (today):
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"

curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "system_prompt": "You are a helpful assistant. Keep replies concise.",
    "llm": { "mode": "hosted", "tier": "fast" },
    "sms": { "mode": "none" }
  }'
```

## Force A Specific Model (Advanced)

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "system_prompt": "You are a helpful assistant.",
    "llm": { "mode": "hosted", "model": "openai/amazon/nova-lite" },
    "sms": { "mode": "none" }
  }'
```

## Notes

- The exact hosted models are an implementation detail; use `tier` unless you need a specific override.
- If you’re wrapping TXT CLAW, treat `llm.model` as an advanced escape hatch, not a default.
