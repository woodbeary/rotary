# TXT CLAW BYOK (Bring Your Own Key)

BYOK lets you run TXT CLAW agents using **your own** model provider key (OpenAI, Anthropic, or OpenAI-compatible gateways).

## Recommended Flow

1. Activate Dev API: `https://www.txtclaw.com/dashboard/billing`
2. Create a TXT CLAW API key: `https://www.txtclaw.com/dashboard/api-keys`
3. Set BYOK once for that TXT CLAW key: `PUT /v1/byok`
4. Create agents with: `llm: { "mode": "byok" }`

## Endpoints

- `GET /v1/byok` returns BYOK **metadata only** (never the plaintext provider key)
- `PUT /v1/byok` sets BYOK for the calling TXT CLAW API key
- `DELETE /v1/byok` clears BYOK

## Example (curl)

```bash
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"

curl -sS "$TXTCLAW_API_BASE_URL/v1/byok" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY"
```

Set BYOK:

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/byok" \
  -X PUT \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "openai_compat",
    "api_key": "sk_REPLACE_ME",
    "base_url": "https://gateway.ai.cloudflare.com/v1/ACCOUNT/GATEWAY/compat",
    "model": "openai/amazon/nova-lite",
    "label": "work"
  }'
```

Create a BYOK agent:

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "system_prompt": "You are a helpful assistant. Keep replies concise.",
    "llm": { "mode": "byok" },
    "sms": { "mode": "none" }
  }'
```

## Notes

- BYOK is **per TXT CLAW API key** (account-scoped). You can create many agents after setting it once.
- BYOK keys are stored **encrypted at rest** and are never shown again after set.
- BYOK set operations are rate limited. Respect `Retry-After` on HTTP `429`.
