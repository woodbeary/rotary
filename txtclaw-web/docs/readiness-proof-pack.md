# Readiness Proof Pack

Run:

```bash
pnpm readiness:proof
```

This command writes dated evidence artifacts to `tmp/readiness-YYYY-MM-DD/` (for example `tmp/readiness-2026-02-20/`), including:

- `launch-gate-strict.log`
- `launch-gate-strict.json` (when parseable)
- `web-reachability-checks.json`
- `docs-e2e-production.log`
- `api-keys-e2e-production.log`
- `service-token-lifecycle.json`
- `sms-live-ops-checklist.md`
- `summary.json`

## `summary.json` schema

```json
{
  "generatedAt": "ISO-8601",
  "dateLabel": "YYYY-MM-DD",
  "baseUrl": "string",
  "outputDir": "string",
  "lanes": {
    "web": { "status": "green|red|unknown", "checks": [] },
    "api": { "status": "green|red|unknown", "checks": [] },
    "byok": { "status": "green|red|unknown", "checks": [] },
    "sms": { "status": "needs-live-ops", "checks": [] }
  },
  "evidence": [
    { "name": "string", "path": "string", "ok": true }
  ],
  "notes": ["string"],
  "automatedDecision": "GREEN|RED",
  "finalDecision": "PENDING_SMS_LIVE_OPS"
}
```

Each check entry includes:

- `name`
- `ok`
- `detail`
- `evidence`
