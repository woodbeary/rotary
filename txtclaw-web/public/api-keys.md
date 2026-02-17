# TXT CLAW API Keys

API keys authenticate requests to the TXT CLAW HTTP API.

## Create a key

1. Create an account: `https://www.txtclaw.com/sign-up`
2. Sign in: `https://www.txtclaw.com/sign-in`
3. Generate a key: `https://www.txtclaw.com/dashboard/api-keys`

Keys are shown **once**. Store it somewhere safe.

Note: email verification is required before you can generate keys.

## Use a key

```bash
export TXTCLAW_API_BASE_URL="https://txtclaw-sms-e2e.lopez731.workers.dev"
export TXTCLAW_API_KEY="vck_REPLACE_ME"
```

All API requests use:

```bash
-H "Authorization: Bearer $TXTCLAW_API_KEY"
```

## Rotate a key (recommended)

1. Generate a new key in the dashboard.
2. Update your app/CI secrets.
3. Revoke the old key in the dashboard.

## Do / don’t

- Do: keep keys in env vars or a secrets manager.
- Do: rotate immediately if you accidentally paste a key into a chat or log.
- Don’t: commit keys to git.
- Don’t: put keys in client-side browser code.
