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
- Do not paste API keys into support tickets; include `trace_id` instead.

## What to avoid

- Don’t ship keys in front-end/browser code.
- Don’t commit keys to git.
- Don’t log `Authorization` headers.
