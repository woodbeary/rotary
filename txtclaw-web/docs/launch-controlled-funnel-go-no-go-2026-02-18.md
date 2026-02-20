# TXT CLAW Controlled Funnel Launch Go/No-Go (2026-02-18)

Scope for this launch:
- Shared/toll-free onboarding flow.
- Billing checkout + plan activation.
- Dev API/docs experience.
- Compliance keyword behavior (`STOP`, `HELP`, `START`).

Out of scope for this launch:
- Dedicated local-number hard launch.
- Any success criteria that depend on A2P/local-number carrier unblock.

## 1) Required deployment values (strict gate)

Web flag:
- `NEXT_PUBLIC_SMS_GATEWAY_LIVE=true`

Worker launch caps:
- `TXTCLAW_MAX_NEW_PER_DAY=5`
- `TXTCLAW_MAX_ACTIVE_USERS=50`
- `TXTCLAW_UNPAID_PROMPTS_PER_DAY=2`

Operational confirmations (set to `1` when verified):
- `LAUNCH_ACK_WEBHOOK_SECRETS_CURRENT=1`
- `LAUNCH_ACK_ONCALL_VISIBILITY=1`

Provider smoke confirmations (set to `1` when verified):
- `LAUNCH_ACK_SMS_ONBOARDING_CHECKOUT=1`
- `LAUNCH_ACK_SMS_STOP_HELP_START=1`
- `LAUNCH_ACK_SMS_WEBHOOK_SIGNATURES=1`
- `LAUNCH_ACK_SMS_PAYMENT_ACTIVATION=1`

## 2) Run strict launch gate

Run from repo root:

```bash
pnpm launch:gate --base-url https://www.txtclaw.com
```

Expected result:
- Script prints a full checklist.
- Final line is `Launch decision: GREEN`.
- Non-zero exit code indicates `RED`.

## 3) Local repo-only gate (no provider/op acknowledgements)

For local engineering validation only:

```bash
pnpm launch:gate:repo
```

This still executes:
- `pnpm biome:check`
- `pnpm typecheck`
- `pnpm lint`
- `pnpm build`
- `pnpm test:e2e`

## 4) Manual provider smoke checklist

Required before marking production GREEN:
1. Inbound to onboarding number returns expected response + checkout path.
2. `STOP`/`HELP`/`START` behavior is correct.
3. Signed Twilio and Square webhook paths validate.
4. Completed payment path activates account in controlled lane.

## 5) Rollback drill

If launch must be rolled back quickly:
1. Set `NEXT_PUBLIC_SMS_GATEWAY_LIVE=false`.
2. Redeploy web.
3. Re-run:

```bash
pnpm launch:gate --skip-repo-gates --skip-smoke --allow-unverified-provider --allow-unverified-ops
```

This confirms rollback flag state without requiring full provider reruns.
