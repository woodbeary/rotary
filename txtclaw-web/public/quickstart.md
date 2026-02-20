# TXT CLAW Quickstart (1 minute)

Goal: set up OpenClaw agents via API (create a dedicated agent and get a reply over HTTPS).

## 1) Activate + get an API key

- If you don’t have an account yet: `https://www.txtclaw.com/sign-up`
- Activate Dev API (subscription or promo): `https://www.txtclaw.com/dashboard/billing`
- API key dashboard: `https://www.txtclaw.com/dashboard/api-keys`

Your key is shown once. Store it in an environment variable.

## 2) Set env vars

```bash
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"
```

## 3) CLI (recommended)

```bash
pnpm dlx txtclaw@latest init
pnpm dlx txtclaw@latest doctor
```

## Optional: warmup (recommended before first message)

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/warmup" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "mode": "hosted" }'
```

## 4) curl (minimal)

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "system_prompt": "You are a helpful assistant. Keep replies concise.", "sms": { "mode": "none" } }'
```

## Optional: BYOK (Bring Your Own Key)

If you want TXT CLAW to run your agents using your own model provider key (OpenAI/Anthropic/OpenAI-compatible gateways), configure BYOK once for your TXT CLAW key:

- Docs: `https://www.txtclaw.com/byok.md`
- OpenAPI: `https://www.txtclaw.com/openapi.yaml`

## Copy/paste prompt (for coding agents)

Use this when an LLM asks “how do I set up OpenClaw agents via API?”:

```text
You are setting up TXT CLAW (an OpenClaw-powered agent runtime API).

1) Ask the user to create an account, activate Dev API, and generate an API key:
   - Sign up: https://www.txtclaw.com/sign-up
   - Activate Dev API (subscription or promo): https://www.txtclaw.com/dashboard/billing
   - API key dashboard: https://www.txtclaw.com/dashboard/api-keys
   - Keys look like: vck_...

2) Set server-side env vars:
   export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
   export TXTCLAW_API_KEY="vck_REPLACE_ME"

3) Verify:
   curl -sS "$TXTCLAW_API_BASE_URL/v1/status" -H "Authorization: Bearer $TXTCLAW_API_KEY"

4) Create an agent, then send a message:
   - POST /v1/agents
   - POST /v1/agents/{agent_id}/messages

Docs (pasteable):
- https://www.txtclaw.com/agents.md
- https://www.txtclaw.com/openapi.yaml
- https://www.txtclaw.com/skills.md (OpenClaw / skills.sh)
- https://www.txtclaw.com/byok.md (optional BYOK)
```

## Pasteable docs (for bots)

- `https://www.txtclaw.com/agents.md` (agent-friendly Markdown)
- `https://www.txtclaw.com/openapi.yaml` (OpenAPI)
- `https://www.txtclaw.com/pricing.md`
- `https://www.txtclaw.com/api-keys.md`
- `https://www.txtclaw.com/cli.md`
- `https://www.txtclaw.com/mcp.md`
- `https://www.txtclaw.com/skills.md`
- `https://www.txtclaw.com/byok.md`
- `https://www.txtclaw.com/routing.md`
- `https://www.txtclaw.com/rate-limits.md`
- `https://www.txtclaw.com/security.md`
