# TXT CLAW Developer API (Preview)

TXT CLAW lets you set up OpenClaw agents via API: create a dedicated OpenClaw agent (memory + configuration) and talk to it over HTTPS.

SMS/iMessage are optional lanes. The **runtime API works without Twilio**.

## Quickstart (1 line)

```bash
pnpm dlx txtclaw@latest init
```

Alias (same CLI):

```bash
pnpm dlx textclaw@latest init
```

## Links

- Quickstart (paste this into bots): `https://www.txtclaw.com/quickstart.md`
- OpenAPI: `https://www.txtclaw.com/openapi.yaml`
- Website: `https://www.txtclaw.com/api-reference`
- API keys: `https://www.txtclaw.com/dashboard/api-keys`
- BYOK (optional): `https://www.txtclaw.com/byok.md`
- Routing (hosted router lane): `https://www.txtclaw.com/routing.md`
- Skills (OpenClaw / skills.sh): `https://www.txtclaw.com/skills.md`

## Tracing / Debugging

- Every response includes `trace_id` and also sets the `x-txtclaw-trace-id` header.
- If you report an issue, include the `trace_id`.

## Environment Variables

```bash
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"
```

## HTTP API

### 1) Create an agent

```bash
curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "system_prompt": "You are a helpful assistant. Keep replies concise.",
    "sms": { "mode": "none" }
  }'
```

### 2) Send a message

```bash
export AGENT_ID="agt_REPLACE_ME"

curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "text": "Draft a polite text asking my landlord to fix a leak." }'
```

## Rate Limits (Preview)

- If you get HTTP `429`, respect the `Retry-After` header and retry later.

## JavaScript SDK (optional)

```bash
pnpm add txtclaw
```

```js
import { createTxtclawClient } from "txtclaw"

const client = createTxtclawClient({
  apiKey: process.env.TXTCLAW_API_KEY,
  baseUrl: process.env.TXTCLAW_API_BASE_URL, // optional
})

const { agent_id } = await client.createAgent({
  systemPrompt: "You are a helpful assistant. Keep replies concise.",
})

const { reply_text } = await client.sendMessage(agent_id, {
  text: "Summarize this in one paragraph: ...",
})

console.log(reply_text)
```

## MCP (optional)

```bash
pnpm dlx txtclaw@latest init --mcp
```

## BYOK (Bring Your Own Key) (optional)

If you want TXT CLAW to run agents using your own provider key:

1) Configure BYOK once:
   - `PUT /v1/byok`
2) Create agents with:
   - `llm: { "mode": "byok" }`

Docs: `https://www.txtclaw.com/byok.md`

## SMS Lanes (Preview)

- `runtime-only`: works now (no SMS).
- `managed`: SMS provisioning is async and may require compliance steps.
- `byo_twilio`: coming soon (bring your own Twilio credentials).
