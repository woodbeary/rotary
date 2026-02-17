# TXT CLAW Rate Limits (Preview)

If you receive HTTP `429`, you are rate limited.

## Defaults (preview)

These defaults may change, but are the current intended starting point:

- `60 req/min` per API key
- `120 req/min` per IP (backstop)
- `1,000 req/day` per API key
- Agent creates: `50/day` per API key, `10/min` per IP
- BYOK set/update: `5/hour` per API key (for `/v1/byok` and `llm.api_key` on agent creation)
- Warmup: `3/hour` per API key (for `POST /v1/warmup`)

## Plan caps (defaults)

These are the default plan-based overrides (if enabled in the Worker):

| Plan | req/min per key | req/min per IP | req/day per key |
| --- | ---: | ---: | ---: |
| Free | 60 | 120 | 1,000 |
| Pro | 300 | 500 | 10,000 |
| BYOK | 600 | 1,000 | 50,000 |

## What to do

1. Respect the `Retry-After` response header (seconds).
2. Retry after the delay (with jitter/backoff).

## Error shape

Rate limited responses include:
- `error: "rate_limited"`
- `trace_id`
- `limit_key` (which limiter triggered)
