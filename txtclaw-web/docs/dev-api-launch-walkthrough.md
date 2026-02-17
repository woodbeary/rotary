# TXT CLAW Dev API: Launch Walkthrough (End-to-End)

This is the “show-your-work” checklist for verifying:
- self-serve API keys
- docs URLs for bots
- the runtime API calls (`/v1/*`)
- rate limits + safety caps
- hosted router + BYOK lanes

## Prereqs

### Worker (`woodbeary/openclaw-saas`)

Set secrets/vars on the Worker:

- `TXTCLAW_PUBLIC_API_ENABLED=true`
- `TXTCLAW_CONSOLE_SERVICE_TOKEN=...` (shared secret; server-to-server only)
- `TXTCLAW_CONSOLE_SERVICE_TOKEN_NEXT=...` (optional rotation window)
- `TXTCLAW_PUBLIC_API_RPM_PER_KEY=60` (default)
- `TXTCLAW_PUBLIC_API_RPM_PER_IP=120` (default)
- `TXTCLAW_PUBLIC_API_REQ_PER_DAY_PER_KEY=1000` (default)

Plan-based overrides (optional):

- `TXTCLAW_PUBLIC_API_RPM_PER_KEY_PRO=300` (default)
- `TXTCLAW_PUBLIC_API_RPM_PER_IP_PRO=500` (default)
- `TXTCLAW_PUBLIC_API_REQ_PER_DAY_PER_KEY_PRO=10000` (default)
- `TXTCLAW_PUBLIC_API_RPM_PER_KEY_BYOK=600` (default)
- `TXTCLAW_PUBLIC_API_RPM_PER_IP_BYOK=1000` (default)
- `TXTCLAW_PUBLIC_API_REQ_PER_DAY_PER_KEY_BYOK=50000` (default)
- `TXTCLAW_PUBLIC_API_OPENCLAW_TIMEOUT_MS=180000` (default)
- `TXTCLAW_PUBLIC_API_OPENCLAW_MAX_ATTEMPTS=2` (default)
- `TXTCLAW_PUBLIC_API_PREWARM_ON_CREATE=true` (default)

BYOK (optional, recommended for launch):

- `TXTCLAW_BYOK_ENABLED=true`
- `TXTCLAW_CREDENTIALS_MASTER_KEY=...` (base64url 32 bytes; AES-256-GCM)
- `TXTCLAW_BYOK_SET_PER_HOUR_PER_KEY=5` (default)

Deploy:

```bash
cd /Users/jacoblopez/code/openclawsaas
pnpm install
pnpm test
pnpm run deploy:txtclaw
```

Real deployed E2E (does not print API keys):

```bash
cd /Users/jacoblopez/code/openclawsaas
TXTCLAW_E2E_CONSOLE_SERVICE_TOKEN="..." pnpm run e2e:dev-api
```

### Website (`woodbeary/txtclaw`)

Set env vars in Vercel (or locally):

- `CLERK_SECRET_KEY=...`
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=...`
- `NEXT_PUBLIC_APP_URL=https://www.txtclaw.com`
- `TXTCLAW_CONSOLE_BASE_URL=https://txtclaw-sms-e2e.lopez731.workers.dev`
- `TXTCLAW_CONSOLE_SERVICE_TOKEN=...` (must match Worker secret)
- `NEXT_PUBLIC_TXTCLAW_API_BASE_URL=https://txtclaw-sms-e2e.lopez731.workers.dev`

## Automated checks (local)

Website:

```bash
cd /Users/jacoblopez/code/txtclaw
pnpm install
pnpm biome:check
pnpm typecheck
pnpm build
pnpm test:e2e
```

Worker:

```bash
cd /Users/jacoblopez/code/openclawsaas
pnpm install
pnpm test
pnpm run typecheck
```

## Manual walkthrough (production URLs)

### 1) Docs (copy/paste URLs)

Verify these return `200` in a browser:

- `https://www.txtclaw.com/quickstart.md`
- `https://www.txtclaw.com/agents.md`
- `https://www.txtclaw.com/openapi.yaml`

### 2) Create an API key

1. Go to `https://www.txtclaw.com/dashboard/api-keys`
2. Click **Generate key**
3. Click **Copy env snippet**

You should see a key that looks like `vck_...` (shown once).

Note: key generation requires a verified email.

### 3) Verify with curl

```bash
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"

curl -sS "$TXTCLAW_API_BASE_URL/v1/status" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY"
```

Expected:
- HTTP `200`
- JSON with `ok: true`
- `trace_id` present (also check `x-txtclaw-trace-id` header)

### 4) Create agent + send message

Optional (recommended on a cold start): warm the gateway.

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/warmup" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "mode": "hosted" }'
```

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "system_prompt": "You are a helpful assistant. Keep replies concise.", "sms": { "mode": "none" } }'
```

Take `agent_id` and send a message:

```bash
export AGENT_ID="agt_REPLACE_ME"

curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "text": "Reply with a one sentence summary of the word: supercalifragilisticexpialidocious" }'
```

Expected:
- HTTP `200`
- `reply_text` non-empty
- `trace_id` present

Note: the first request for a brand-new API key may take longer while the gateway warms. New keys are automatically prewarmed on creation to reduce this.

### 5) Revoke key

1. Return to `https://www.txtclaw.com/dashboard/api-keys`
2. Revoke the key
3. Re-run `/v1/status` with the revoked key

Expected:
- HTTP `401`

### 6) Billing (optional)

1. Go to `https://www.txtclaw.com/dashboard/billing`
2. Complete checkout
3. Worker plan sync happens automatically via the Square webhook:
   - `POST /console/v1/plan/sync` with `{ user_id, offer_code, paid_at }`
4. After payment, your plan caps apply to new traffic (RPM + daily caps)

## X launch checklist (copy/paste)

- `https://www.txtclaw.com/developers` loads on mobile (no horizontal scroll)
- `https://www.txtclaw.com/quickstart.md` returns 200
- `https://www.txtclaw.com/openapi.yaml` returns 200
- Can sign in and generate/revoke key at `/dashboard/api-keys`
- `/v1/status` works with a fresh key
- `/v1/agents` + `/v1/agents/:id/messages` works
- Rate limiting returns `429` with `Retry-After`
