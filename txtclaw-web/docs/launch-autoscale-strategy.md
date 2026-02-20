# TXT CLAW North Star: Production Launch and Scale Plan

Status: authoritative architecture + execution guide
Owner: Jacob Lopez
Last updated: 2026-02-11

This document is the single source of truth for building and launching TXT CLAW with:
- Cloudflare Workers + Sandboxes (OpenClaw runtime)
- Twilio (onboarding number + dedicated customer numbers)
- Square (hosted subscription checkout)
- Vercel/Next.js (marketing + lightweight control endpoints)

## 1) Product Truth

TXT CLAW is a phone-first SaaS.

Core user journey:
1. User texts the main onboarding number.
2. User receives a hosted Square subscription link by SMS.
3. User pays.
4. System provisions:
   - dedicated Twilio number
   - dedicated Cloudflare sandbox runtime running OpenClaw
5. User texts their dedicated number and uses their private agent.

Principles:
- No self-managed relational DB.
- Minimal maintenance.
- Strong idempotency and safe retries.
- Cost-aware autoscale.
- Freeze immediately on failed renewal.
- Reclaim inactive resources to protect margin.

## 2) Current External Status (as of 2026-02-11)

- Twilio brand: Registered (Low Volume Standard)
- A2P campaign: In progress (not yet fully usable for 10DLC production traffic)
- Toll-free verification: Verification in progress

Launch implication:
- Build and fully test now.
- Public production launch sequencing depends on toll-free/A2P approval states.

Operational hardening references for this launch plan:
- `/docs/anti-abuse-compliance-readiness-matrix-10dlc.md`
- `/docs/anti-abuse-instrumentation-specification.md`
- `/docs/anti-abuse-kyc-and-escalation-playbook.md`

## 3) Architecture (Final)

### 3.1 Control Plane

Cloudflare Worker in `/Users/jacoblopez/code/openclawsaas` handles:
- Twilio inbound webhooks
- Square webhooks
- Provisioning orchestration
- Lifecycle/cleanup jobs
- Policy/rate-limit enforcement

Managed state only:
- Durable Objects: strongly consistent control state and locking
- R2: runtime persistence snapshots/backups
- Optional KV: non-critical cache/lookups only

### 3.2 Data Plane

Per-customer sandbox instance:
- one customer -> one sandbox key
- example key: `cust:+1XXXXXXXXXX`

OpenClaw gateway runs inside the sandbox.
Persistence is restored/synced via R2 prefix per customer.

Important:
- Do not deploy one Worker per customer.
- Use one Worker and isolate via unique sandbox keys.

### 3.3 Billing + Telephony

Square:
- Use hosted recurring checkout links.
- SMS link to user.
- Correlate payment to sender phone using deterministic checkout token/reference.

Twilio:
- Main onboarding number remains permanent.
- Dedicated local numbers assigned post-payment.
- Dedicated number only responds to owner phone.

## 4) Why This Scales

Scale model:
- millions of accounts
- bounded concurrent active sandboxes
- sleep when idle
- wake on demand
- async queue processing for bursts

Do not assume unlimited concurrent containers.
Design for queueing + graceful latency under load.

## 5) Customer Identity and Security

Primary identity:
- E.164 sender phone number

Rules:
- Normalize all phone numbers to E.164.
- Verify Twilio signature for inbound webhook requests.
- Verify Square webhook signatures.
- Enforce dedicated-number ownership on each inbound message.
- Redact secrets/PII from logs.

## 6) State Model

Customer states:
- `new`
- `pending_payment`
- `provisioning`
- `active`
- `frozen`
- `cleanup_pending`
- `terminated`

Minimum required fields:
- `from_phone`
- `status`
- `plan`
- `square_subscription_id`
- `square_customer_id` (if available)
- `twilio_dedicated_number`
- `twilio_incoming_sid`
- `sandbox_key`
- quota counters
- lifecycle timestamps
- opt-out metadata

## 7) Production Flows

### 7.1 Unpaid inbound SMS to onboarding number

1. Validate request signature.
2. Apply unpaid response throttle.
3. Create/reuse checkout token mapped to sender phone.
4. Create/reuse Square hosted payment link.
5. Reply with concise onboarding SMS + payment link.

### 7.2 Payment webhook

1. Validate Square signature.
2. Idempotency check (`event_id`).
3. Resolve checkout token/order -> sender phone.
4. Enforce launch caps (5/day, 50 total).
5. Mark provisioning queued.
6. Enqueue provisioning job.

### 7.3 Provisioning job

1. Acquire per-customer provisioning lock.
2. Buy available Twilio local number (preferred area code if available).
3. Attach webhook to purchased number.
4. Create or warm customer sandbox.
5. Bootstrap OpenClaw runtime.
6. Persist ownership + runtime mapping.
7. Send activation SMS to user with dedicated number.

### 7.4 Dedicated number inbound

1. Verify sender owns the dedicated number.
2. Enqueue user message for serialized handling.
3. Return immediate TwiML response (no long hold).
4. Worker processes queue:
   - wake sandbox if sleeping
   - call OpenClaw HTTP endpoint
   - send outbound SMS via Twilio REST API

## 8) Usage Limits, Rate Limits, and Margin Protection

Global launch controls:
- max new activations/day: 5
- max active paid users: 50

Per-user limits:
- outbound SMS limit (daily + monthly)
- LLM spend budget limit (daily + monthly)
- warn at 80%, cap at 100%

Unpaid sender throttling:
- first inbound: full onboarding response
- subsequent inbound: very limited reminders
- hard cap to avoid cost leakage

## 9) Plan Policy

Plans:
- Pro: negotiable only within strict deterministic bounds
- Max: fixed
- BYOK: fixed

Negotiation safeguards:
- deterministic discount ladder, bounded attempts
- never open-ended model loop before payment
- enforce floor price and minimum margin

## 10) Reliability Guardrails

Self-healing and safe defaults:
- health check before/after generation jobs
- auto-restart on gateway hangs
- retry with bounded backoff
- dead-letter path for repeated failures
- revert to known-good config when model/provider misconfig detected
- BYOK key/config validation before activation

## 11) Customer Self-Serve via SMS (No Email Support Dependency)

Required commands:
- `HELP`
- `STATUS`
- `BILLING`
- `RESTART`
- `RESET`
- `STOP`
- `START`

Behavior:
- compliance keywords must always work
- give clear one-message status and next action

## 12) Resource Lifecycle and Cost Control

- sleep sandboxes after inactivity for lower-cost tiers
- keep warm longer for higher tiers if needed
- freeze immediately on failed renewal
- inactivity reaper:
  - send warning
  - release Twilio number after grace window
  - archive/delete runtime state per retention policy

## 13) Launch Strategy

### Phase 1 (while A2P local-number path is pending)
- Launch through approved toll-free onboarding path.
- Keep onboarding and primary interactions reliable.
- Continue provisioning logic behind feature flags for dedicated numbers.

### Phase 2 (after A2P campaign registered)
- Turn on default dedicated local-number provisioning for paid users.
- Migrate existing users by SMS prompts and dual-number grace period.

### Phase 3
- remove initial 5/day and 50 total caps after stability and margin thresholds are met.

## 14) E2E Test Matrix (Real Integrations Only)

No mock-only signoff. Real integration checks required:

1. Twilio inbound -> checkout link SMS
2. Square webhook -> provisioning start
3. Twilio number purchase + webhook assignment
4. Activation SMS delivered
5. Dedicated inbound -> OpenClaw response via async pipeline
6. Duplicate Twilio webhook does not duplicate side effects
7. Duplicate Square webhook does not double-provision
8. STOP blocks non-compliance outbound
9. START re-enables outbound
10. Ownership enforcement on dedicated number
11. Failed renewal -> frozen immediately
12. Over-quota enforcement (warn + cap)
13. Inactivity cleanup releases paid resources correctly

## 15) Go/No-Go Criteria

Go live only when all are true:
- signatures verified in production for Twilio + Square
- idempotency proven under duplicate webhook replay
- provisioning retries and dead-letter behavior verified
- async messaging path stable with cold starts
- quota/freeze/cleanup policies validated end-to-end
- dashboard logs provide enough evidence to debug without manual shell access

## 16) Concrete Build Sequence

1. Multi-tenant sandbox support and per-customer sandbox keys
2. Per-customer R2 backup/restore prefixes
3. Async message processing pipeline (queue-based)
4. Square subscription correlation + webhook hardening
5. Twilio provisioning hardening + number ownership enforcement
6. Quota and launch-cap enforcement in backend
7. Lifecycle automations (freeze/unfreeze/cleanup)
8. Real E2E test runbook and execution evidence

## 17) Non-Negotiables

- No destructive operations without explicit intent.
- No hardcoded secrets in repo.
- No fake demo mode used for production signoff.
- All changes must pass build and tests in CI-equivalent commands.

## 18) Future Extensions (Post-MVP)

- Voice/calling actions from dedicated numbers
- Tier-based always-on runtime behavior
- richer BYOK guardrails and diagnostics
- optional customer profile pages

## 19) Implementation Status Snapshot (2026-02-11)

Implemented now in `/Users/jacoblopez/code/openclawsaas`:
- customer runtime identity fields (`sandboxKey`, `r2Prefix`) in TXT CLAW records
- per-customer runtime key derivation from E.164 sender phone
- dedicated inbound path upgraded from placeholder to OpenClaw runtime call path
- async-safe dedicated inbound handling (immediate webhook response + background processing)
- launch-cap enforcement in backend webhook path (`max active`, `max new/day`)
- cron sync expanded to include active customer runtimes (per-customer R2 prefix)
- gateway env override support for per-customer runtime boot context
- startup script support for per-customer R2 prefix restore/sync paths
- OpenClaw responses HTTP endpoint enabled during startup config build
- container concurrency updated (`max_instances: 25`)

Validated now:
- `openclawsaas`: `npm test`, `npm run typecheck`, `npm run build`
- `txtclaw`: `pnpm build`

## 20) Live Staging Validation Snapshot (2026-02-11)

Staging worker used:
- `https://txtclaw-sms-e2e.lopez731.workers.dev`

Validated with real provider signatures and API calls:
- Twilio signature verification:
  - invalid signature returns Unauthorized TwiML
  - valid signed inbound requests accepted
- Onboarding flow:
  - signed inbound to onboarding number returns Square checkout link
  - unpaid prompt throttling enforced (third message returned empty TwiML when cap reached)
- Square webhook flow:
  - signed `payment.updated` (`COMPLETED`) webhook provisions dedicated number
  - signed `subscription.updated` (`CANCELED`) webhook freezes account
- Dedicated number routing:
  - owner inbound receives async ack (empty TwiML, background processing)
  - non-owner inbound receives private-number denial
  - owner inbound after freeze receives inactive guidance
- Usage limit enforcement:
  - with temporary low monthly fast-request cap, first dedicated inbound accepted, second blocked with usage-limit message

Real SMS transport verification:
- Twilio API send from onboarding number to Twilio Virtual Phone succeeded and reached `delivered` state.
- Twilio message logs showed inbound/outbound-reply events for the staging numbers.

Notes:
- These checks were executed against real Twilio/Square accounts and signed webhook flows (not local-only mocks).
- Remaining launch hardening should focus on queue workers, renewal edge-cases, and cleanup automation intervals.

## 21) Additional Live Validation Snapshot (2026-02-11, later run)

Staging worker:
- `txtclaw-sms-e2e` (latest upload + secret-change deployments)

What was validated end-to-end with signed requests:
- Twilio webhook auth:
  - invalid `X-Twilio-Signature` rejected with `Unauthorized`
  - valid signature accepted
- Onboarding + wait-to-pay behavior:
  - first/second signed onboarding inbound returned same Square checkout link
  - third unpaid prompt for same sender returned empty TwiML (throttle)
- Keyword compliance:
  - `HELP` returns support + STOP guidance
  - `STOP` suppresses later non-keyword replies
  - `START` resubscribes
- Real payment provisioning path:
  - extracted real `order_id` from Square sandbox checkout payload
  - sent signed `payment.updated` (`COMPLETED`) webhook for that order
  - worker provisioned dedicated Twilio number and marked user active
- Dedicated number access control:
  - owner sender receives async ack (empty TwiML)
  - non-owner receives private-number denial
- Replay/idempotency:
  - duplicate Twilio `MessageSid` request returns empty TwiML on replay (no duplicate side effects)
  - duplicate Square `event_id` returns `{ "ok": true, "ignored": true }`
- Subscription lifecycle states:
  - signed `subscription.updated` `PAUSED` -> user `frozen`
  - signed `subscription.updated` `ACTIVE` -> user `active`
  - signed `subscription.updated` `CANCELED` -> user `frozen`
- Invalid/unsupported webhook safety:
  - invalid Square HMAC signature returns `401 Invalid signature`
  - unsupported Square event type is acknowledged and ignored
- Non-completed payment behavior:
  - signed `payment.updated` with `status != COMPLETED` returns `reason: not_completed` and freezes the user
- Usage/cost accounting visibility:
  - `STATUS` keyword reported current state and counters:
    - inbound/outbound daily
    - fast-requests monthly
    - estimated spend in cents
- Fast-request cap enforcement:
  - temporarily set `TXTCLAW_PRO_FAST_REQUESTS_MONTH=2` on staging
  - reactivated user and confirmed dedicated inbound returns usage-limit message
  - restored cap back to `500`
- Twilio transport reality check:
  - sent real API SMS from onboarding number to Twilio Virtual Phone
  - message reached `delivered`

Operational note for this staging worker:
- to make Square signature tests deterministic, staging `SQUARE_WEBHOOK_SIGNATURE_KEY` was rotated to a known test key.
- if you want automatic Square-generated test webhooks to continue on this same staging worker, regenerate/update the Square webhook subscription signature key to match this worker secret.

## 22) Full Live Matrix (2026-02-11, current revision)

Code revision deployed to staging worker:
- `txtclaw-sms-e2e` version `bf777b76-9811-49ae-864e-180c55c1066c`

Matrix execution summary:
- Total checks: `18`
- Passed: `17`
- Failed: `1`

Passed (live, signed, provider-backed):
- Twilio webhook invalid signature rejection
- Onboarding initial response includes assistant copy + checkout link + offer
- Negotiation decreases offer by `$1` per message and rotates checkout links
- Unpaid prompt throttling
- Twilio webhook replay idempotency
- Square webhook invalid signature rejection
- Payment completed -> dedicated number provisioning
- Square webhook replay idempotency

## 23) Runtime Fix Notes (2026-02-11, latest)

Validated working AI gateway path for OpenClaw in staging:
- `AI_GATEWAY_BASE_URL=https://ai-gateway.vercel.sh/v1`
- `AI_GATEWAY_API_KEY=<vck_...>`
- `AI_GATEWAY_MODEL=amazon/nova-lite`
- `TXTCLAW_FORCE_OPENAI_COMPAT=true`
- `MOLTBOT_GATEWAY_TOKEN=<non-empty token>`

What this fixed:
- eliminated startup crashes caused by missing gateway token when binding to `lan`
- eliminated provider mismatch that was selecting `anthropic` without auth
- dedicated OpenClaw replies now generate real content (example: prompt `Say YES only` returned `YES`)

Known remaining transport constraint:
- dedicated local-number outbound to real US mobiles is still `undelivered` with Twilio `error_code=30034`
- this is expected until A2P registration state allows that traffic
- dedicated sends to Twilio Virtual Phone are deliverable and remain useful for E2E validation pre-approval
- Dedicated owner accepted (async path)
- Dedicated non-owner blocked
- Subscription `PAUSED` -> frozen
- Subscription `ACTIVE` -> active
- Payment non-completed -> frozen
- OpenClaw dedicated inbound path accepted (async)
- Dedicated outbound SMS reply observed from dedicated number
- `STATUS` keyword telemetry response

Single failing check:
- `openclaw-not-warming-fallback`
  - Observed reply body: `"Your agent is warming up. Please try again in a moment."`
  - Interpretation: dedicated reply pipeline is functioning, but model inference is not configured for real responses yet.

Root-cause blocker:
- Worker secrets currently include Twilio/Square control-plane credentials but do **not** include a live model provider path (`ANTHROPIC_API_KEY`, or AI Gateway provider credentials/base URL, or equivalent).
- Result: OpenClaw request path enters fallback mode instead of returning model-generated text.

Guardrail added:
- OpenClaw request timeout with fallback handling (`TXTCLAW_OPENCLAW_TIMEOUT_MS`, default `20000ms`) to prevent hangs from causing silent no-reply behavior.

Post-test staging secret restoration:
- launch caps reset to intended values:
  - `TXTCLAW_MAX_NEW_PER_DAY=5`
  - `TXTCLAW_MAX_ACTIVE_USERS=50`
  - `TXTCLAW_UNPAID_PROMPTS_PER_DAY=2`
