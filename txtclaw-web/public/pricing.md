# TXT CLAW Dev API Pricing (Preview)

Day 1 billing is intentionally simple: fixed plans + hard quotas enforced in the Worker.

Checkout: `https://www.txtclaw.com/dashboard/billing` (requires sign-in).

## Free (default)

- Browse docs + dashboard
- No API keys (subscription or promo required)

## Pro (monthly)

- $16/mo (launch early bird) then $19/mo
- Higher plan caps (no code changes)

## BYOK (one-time / lifetime)

- $299 one-time
- BYOK lane (`PUT /v1/byok` + `llm.mode="byok"`)
- Higher plan caps (no code changes)

## Notes

- Exact limits per plan are documented in `https://www.txtclaw.com/rate-limits.md`.
- BYOK keys are stored encrypted and are never returned after initial set.
- If you need higher limits or team accounts, we can raise caps per account (launch week).
