# TXT CLAW Security Notes

## API keys

- Keys are shown once on creation.
- The service stores **hashed** keys for validation (plaintext keys are not stored).
- Revoke keys anytime in the dashboard.

## BYOK (Bring Your Own Key)

- BYOK provider keys are stored **encrypted** at rest (AES-256-GCM).
- Plaintext BYOK keys are never returned after initial set.

## Logging / tracing

- Every API response includes `trace_id` and sets `x-txtclaw-trace-id`.
- Every SMS outbound attempt is logged with trace lineage and actor/state correlation fields planned in the anti-abuse schema.
- Do not log `Authorization` headers.
- Do not log message plaintext.

## SMS compliance controls (now enabled for admin workflows)

- Trace IDs are the primary evidence chain for all compliance actions.
- Actor-level abuse controls are reversible by default:
  - `warn_actor`
  - `pause_actor_egress`
  - `disable_actor_numbers`
  - `unfreeze_actor`
- Operator actions must include a reason and event evidence (trace IDs) for auditability.

## What to avoid

- Don’t ship keys in front-end/browser code.
- Don’t commit keys to git.
- Don’t log `Authorization` headers.
