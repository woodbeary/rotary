# Launch Autoscale Readiness Report (Controlled Funnel)

Date: 2026-02-18
Run completed: 2026-02-18 14:45 PST
Decision: **RED**

## Scope
- In scope: controlled funnel only (shared onboarding lane + checkout + Dev API/docs).
- Out of scope: dedicated local-number hard launch and carrier-unblocked local delivery.

## Strict Results Summary
- Repo gate rerun: **RED**
  - Failing check: `pnpm biome:check`
  - Evidence: `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/launch-gate-repo-rerun-2026-02-18.txt`
- Production smoke gate rerun (no repo gate): **RED**
  - Smoke pages/docs: PASS
  - Provider/ops acks required for strict launch: FAIL
  - Evidence: `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/launch-gate-prod-smoke-rerun-2026-02-18.txt`
- Post-cutover strict gate rerun: **RED** (`PASS 13 | FAIL 7`)
  - Repo `biome/typecheck/lint/build`: PASS
  - Repo `test:e2e`: FAIL (Clerk test sign-in tickets invalid in `api-keys.e2e` suite)
  - Missing required provider/ops ack flags remain.
  - Evidence:
    - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/launch-gate-post-cutover-2026-02-18.txt`
    - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/launch-gate-post-cutover-baseurl-2026-02-18.txt`

## Checks Executed

Worker deployment during this incident run:
- Worker: `txtclaw-sms-e2e`
- Version: `9b5b659f-2e3e-4654-b8cc-897a0b81f3ab`

### 1) Web + docs smoke
- Production web redeployed to approved line `+18554088675`:
  - `https://www.txtclaw.com` now renders `sms:+18554088675`
- `/developers`: PASS
- `/quickstart.md`: PASS
- `/openapi.yaml`: PASS
- `/rate-limits.md`: PASS
- `/pay` redirect behavior: PASS
- Evidence: `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/launch-gate-prod-smoke-rerun-2026-02-18.txt`

### 2) Twilio webhook logic (signed replay)
- Signed replay to `+18554088675`: returns onboarding/checkout lane response
- Signed replay to `+18662511599`: returns "This number isn’t active for you... +18554088675"
- STOP/HELP/START compliance flow: PASS
- Evidence:
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-signed-replay-9493066291-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-keyword-flow-9493066291-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-onboarding-replay-9493066291-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-cutover-signed-replay-855-vs-866-2026-02-18.json`

### 3) Twilio credential health
- User-provided tokens were stored in environment:
  - worker secret updated: `TWILIO_AUTH_TOKEN`
  - worker secret added: `TWILIO_TEST_AUTH_TOKEN`
  - local env updated: `/Users/jacoblopez/code/openclawsaas/.dev.vars`
- Twilio REST auth check with available configured credential set:
  - `account_sid + auth_token`: `401 Authenticate`
  - `api_key_sid + api_key_secret`: `401 Authenticate`
- Twilio onboarding setup script also fails with `401 Authenticate`
- Deployed worker ops endpoint and executed live dry-run sync:
  - `POST /webhooks/twilio/ops/sync-onboarding?dry_run=1`
  - result after user-provided token update: still `Twilio list numbers failed for all configured auth methods` with both:
    - `[api_key] ... 401 Authenticate`
    - `[auth_token] ... 401 Authenticate`
  - confirms currently stored production Twilio credentials are still not valid for Twilio control-plane API calls.
- Token combination probe:
  - `test_sid + test_token` returns Twilio `403 Resource not accessible with Test Account Credentials` (expected for test credentials against this endpoint).
  - `prod_sid + prod_token` returns `401 Authenticate`.
- Approved-account probe for `AC_ACCOUNT_SID_REDACTED`:
  - known candidate token(s) in local env/session history return `401 Authenticate`.
  - user-confirmed live credential set (`AC99...` + provided auth token) also returns `401 Authenticate`.
  - no valid API key pair for `AC99...` is available in this workspace.
- Evidence:
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-auth-health-check-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-sync-dryrun-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-sync-dryrun-after-user-token-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-sync-write-after-user-token-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-credential-combo-check-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-credential-check-user-confirmed-2026-02-18.json`
  - `/Users/jacoblopez/code/txtclaw/tmp/launch-2026-02-18/twilio-signed-replay-with-user-token-2026-02-18.json`

### 4) Dev API lifecycle (live)
- Plan set -> key create -> `/v1/status` success -> key revoke -> `/v1/status` returns `401`
- Result: PASS
- Evidence: captured command output in run log (user `launch_probe_1771452248684`)

### 5) E2E browser suites
- `tests/docs.spec.ts`: PASS
- `tests/api-keys.e2e.spec.ts`: FAIL (paid-user promo redemption flow timed out waiting for `/api/promo/redeem` response)
- Full `pnpm test:e2e` in strict gate after cutover with `BASE_URL=https://www.txtclaw.com`:
  - docs suite: PASS
  - `api-keys.e2e` sign-in tests: FAIL (Clerk ticket invalid for generated test users)
- Evidence:
  - Playwright output in terminal for run at ~14:00 PST

### 6) Worker code health
- `openclawsaas`: `pnpm biome:check` PASS, `pnpm typecheck` PASS
- `src/txtclaw/twilio.test.ts` + `src/txtclaw/square.test.ts`: PASS
- `src/txtclaw/routes.test.ts`: PASS

## Blocking Findings (Launch-Critical)

1. **Unverified real Twilio inbound delivery for customer handset (P0)**
- User-reported production failure from `+19493066291` (no reply).
- Signed replay proves worker logic responds when requests reach webhook, but this is not equivalent to Twilio control-plane delivery.

2. **Twilio credential/auth state is not trusted (P0)**
- Active configured credential set fails Twilio API auth with `401 Authenticate` for both auth modes.
- Approved `+18554088675` lane is on account `AC99...`, but no currently valid `AC99...` auth token/API key is available in deployment context.
- This prevents proving webhook assignment correctness via Twilio API and raises reliability risk for any worker-initiated Twilio REST sends.

3. **Repo quality gate failing (P1)**
- `pnpm biome:check` currently failing in `/Users/jacoblopez/code/txtclaw/app/not-found.tsx` formatting.

4. **Paid path E2E not fully green (P1)**
- `tests/api-keys.e2e.spec.ts` paid flow timeout at promo redeem response wait.

## Final Go/No-Go
- **NO-GO (RED)** for autoscale launch window at this time.
- Reason: provider control-plane certainty is incomplete for real inbound from customer handset + strict quality/e2e gates are not fully green.

## Required to Flip RED -> GREEN
1. Reconcile Twilio control-plane credentials and confirm current auth works (`200`) with Twilio REST checks.
2. Confirm webhook assignment for onboarding number `+18554088675` to:
   - `https://txtclaw-sms-e2e.lopez731.workers.dev/webhooks/twilio/sms`
3. Run live handset verification while tailing production logs and capture Twilio-origin request evidence.
4. Clear repo gate failure (`pnpm biome:check`) and rerun strict gate.
5. Resolve Clerk test sign-in ticket issue in `tests/api-keys.e2e.spec.ts` and rerun `pnpm test:e2e` clean.
