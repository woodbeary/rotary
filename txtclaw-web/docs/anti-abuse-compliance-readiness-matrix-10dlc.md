# Anti-Abuse Compliance Readiness Matrix (TXT CLAW)

Status date: **2026-02-18**

## Current known state

- Twilio Trust Hub Brand: registered as **Low Volume Standard**.
- A2P 10DLC campaign: **in progress** (existing docs note local 10DLC production traffic was pending at last verification run).
- SMS consent and STOP language are already documented on-site and reflected in:
  - `/app/sms-consent/page.tsx`
  - `/app/privacy/page.tsx`
  - `/app/terms/page.tsx`
  - `/public/security.md`
- Internal launch notes already validate:
  - webhook auth is enforced;
  - `STOP/START/HELP` command behavior;
  - dedicated ownership enforcement;
  - queue and idempotency checks.

## Matrix: architecture choice vs blast radius

| Control surface | Recommended baseline now | Higher-protection option | Blast radius on abuse | Compliance impact |
| --- | --- | --- | --- | --- |
| Campaign model | One shared `Agents`-style A2P campaign |
Use per-user/customer campaign if legal entity differs | Shared campaign can suspend all traffic if abuse is attributed to campaign-level quality problems. | Shared model is faster to deploy but higher blast radius. |
| Number ownership | Dedicated numbers per user, campaign-owned |
Per-tenant sub-account + per-tenant campaign | Shared number pool is higher blast radius for fraud complaints. | Per-tenant sub-accounts are cleaner for isolation, support, and remediation. |
| Consent capture | Web + SMS disclosure + `STOP` mandatory handling |
Signed consent artifact with timestamp + IP + source page | Poorly captured consent increases rejection risk on audit. |
| Opt-out enforcement | Immediate suppression for `STOP` recipient | Same + hard retention and periodic replay checks | Weak enforcement leads to immediate policy violations and fines. |

## Required evidence set to publish in compliance folder

- Consent artifact fields: actor id, phone, timestamp, source page, wording version.
- Distribution evidence: per-message outbound decision (allowed/blocked), reason for suppression.
- Abuse evidence: per-actor risk score changes and action history.
- Operational evidence: pause/disable action timestamps, operator id, linked `trace_id`s.

## Open research tasks still required

1. Confirm final Twilio Trust Hub profile and campaign type for multi-agent use under your legal entity model.
2. Determine if Twilio permits subaccount-as-account isolation for your chosen product plan before public scale.
3. Confirm 30034 and related error-class handling path in your production worker and whether to escalate to retry policy vs manual support path.
4. Confirm required retention windows for opt-out/consent records under your legal counsel advice.

## Decision defaults for implementation

- Ship now with `Agents` campaign profile + risk controls enabled.
- Keep shared carrier campaign until subaccount compliance design is validated in staging at scale.
- Start with hardcoded reversible controls: **warn → pause (auto-expiring) → disable**.
- Expand to subaccount isolation once abuse telemetry proves sustained high-volume and carrier behavior is stable.
