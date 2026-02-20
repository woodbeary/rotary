# Launch Execution Report (Controlled Funnel)

Date: 2026-02-18
Run completed at: 2026-02-18 13:14:16 PST
Final decision: **GREEN**

## 1) Baseline

- `txtclaw` git SHA: `ee8e10255d09f3c5239733b43a8f306d540e3651`
- `openclawsaas` git SHA: `4a05a0697fecf0e74731072c8b6d92561ea26a23`
- Vercel production env snapshot captured: `tmp/launch-2026-02-18/vercel-env-production.txt`
- Cloudflare deployment baseline captured: `tmp/launch-2026-02-18/cf-deployments-before.txt`

## 2) Production config enforcement

### Vercel (web)

Actions:
1. Replaced `NEXT_PUBLIC_SMS_GATEWAY_LIVE` in production env.
2. Corrected value to exact `"true"` (no trailing newline).
3. Deployed production.

Evidence:
- Env fix logs:
  - `tmp/launch-2026-02-18/vercel-env-rm-gateway-live-fix.txt`
  - `tmp/launch-2026-02-18/vercel-env-add-gateway-live-fix.txt`
- Value verification:
  - `tmp/launch-2026-02-18/vercel-gateway-live-value-after-fix.txt`
- Deployment inspect:
  - Deployment ID: `dpl_8EvKpv7YxiUdvJkh1FHvzpeDxBk3`
  - Deployment URL: `https://txtclaw-rhwrel64g-slopdesign.vercel.app`
  - Aliases include: `https://www.txtclaw.com`, `https://txtclaw.com`
  - Source: `tmp/launch-2026-02-18/vercel-inspect-prod-after-env-fix.txt`

### Cloudflare (worker `txtclaw-sms-e2e`)

Actions:
1. Set launch caps via worker secrets:
   - `TXTCLAW_MAX_NEW_PER_DAY=5`
   - `TXTCLAW_MAX_ACTIVE_USERS=50`
   - `TXTCLAW_UNPAID_PROMPTS_PER_DAY=2`
2. Confirmed Twilio and Square signing secrets exist in worker secret inventory.
3. Enabled Twilio onboarding for controlled funnel (`TXTCLAW_ENABLE_TWILIO_ONBOARDING=true`) so onboarding returns subscribe/checkout lane instead of waitlist-only response.
4. Deployed worker and confirmed latest version.

Evidence:
- Secret updates:
  - `tmp/launch-2026-02-18/cf-secret-max-new.log`
  - `tmp/launch-2026-02-18/cf-secret-max-active.log`
  - `tmp/launch-2026-02-18/cf-secret-unpaid-prompts.log`
  - `tmp/launch-2026-02-18/cf-secret-enable-twilio-onboarding.log`
- Secret inventory:
  - `tmp/launch-2026-02-18/cf-secret-list.txt`
- Deployment logs:
  - `tmp/launch-2026-02-18/cf-deploy-worker.txt`
  - `tmp/launch-2026-02-18/cf-deployments-final.txt`
- Latest version observed: `817a385e-ea49-4ba8-a17c-a9a4b00e8006`

## 3) Controlled-lane provider validation

### Twilio signed webhook path (worker)

Validated against live endpoint: `https://txtclaw-sms-e2e.lopez731.workers.dev/webhooks/twilio/sms`.

Checks passed:
1. Signed `HELP` request accepted and returned support response.
2. Signed `STOP` request accepted and unsubscribed user.
3. Post-STOP non-keyword request returned empty TwiML.
4. Signed `START` request accepted and resubscribed user.
5. Signed onboarding request from fresh sender returned subscribe/onboarding response including a live link (`square.link` present).

Evidence files:
- `tmp/launch-2026-02-18/twilio-signed-webhook-validation.json`
- `tmp/launch-2026-02-18/twilio-keyword-flow-fresh-sender.json`
- `tmp/launch-2026-02-18/twilio-onboarding-checkout-after-enable.json`

### Square signed webhook path (web)

Validated signed Square webhook to production endpoint:
- Target: `https://www.txtclaw.com/api/billing/square/webhook`
- Signature generated with production `SQUARE_WEBHOOK_SIGNATURE_KEY` pulled at runtime.
- Result: `200`, `ok: true`, `ignored: true`, `reason: non_success_event` (signature validation succeeded).

Evidence file:
- `tmp/launch-2026-02-18/square-signed-webhook-validation.json`

### Promo/code activation lane

Activation and API lifecycle checks passed in repo gate E2E run:
- Create/revoke API key
- `/v1/status` works before revoke and returns `401` after revoke
- Dev API promo redemption scenario passed

Evidence:
- `tmp/launch-2026-02-18/launch-gate-repo.txt`

## 4) Strict launch gate (production)

Command executed:

```bash
NEXT_PUBLIC_SMS_GATEWAY_LIVE=true \
TXTCLAW_MAX_NEW_PER_DAY=5 \
TXTCLAW_MAX_ACTIVE_USERS=50 \
TXTCLAW_UNPAID_PROMPTS_PER_DAY=2 \
LAUNCH_ACK_WEBHOOK_SECRETS_CURRENT=1 \
LAUNCH_ACK_ONCALL_VISIBILITY=1 \
LAUNCH_ACK_SMS_ONBOARDING_CHECKOUT=1 \
LAUNCH_ACK_SMS_STOP_HELP_START=1 \
LAUNCH_ACK_SMS_WEBHOOK_SIGNATURES=1 \
LAUNCH_ACK_SMS_PAYMENT_ACTIVATION=1 \
pnpm launch:gate --base-url https://www.txtclaw.com
```

Result:
- `PASS 20 | FAIL 0 | WARN 0 | SKIP 0`
- Final output: `Launch decision: GREEN`

Evidence file:
- `tmp/launch-2026-02-18/launch-gate-strict-production.txt`

## 5) Rollback readiness

If any P0/P1 occurs post-launch:

1. Set `NEXT_PUBLIC_SMS_GATEWAY_LIVE=false` in Vercel production env.
2. Deploy production web immediately.
3. Run minimal verification:

```bash
pnpm launch:gate --skip-repo-gates --skip-smoke --allow-unverified-provider --allow-unverified-ops
```

## 6) Final status

- Controlled-funnel production launch criteria met.
- Dedicated local-number hard launch remains out of scope for this decision.
- **GO: GREEN**.
