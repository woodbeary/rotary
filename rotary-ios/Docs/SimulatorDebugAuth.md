# Simulator Debug Auth

Rotary has a DEBUG-only injected auth path in `RotaryAuthStore`.

## Supported environment variables

- `ROTARY_DEBUG_EMAIL`
- `ROTARY_DEBUG_SESSION_TOKEN`
- `ROTARY_DEBUG_CLIENT_ID`
- `ROTARY_DEBUG_SESSION_ID`
- `ROTARY_DEBUG_DEVICE_TOKEN`

Only `ROTARY_DEBUG_EMAIL` and `ROTARY_DEBUG_SESSION_TOKEN` are required. The others fall back to debug placeholders.

Optional:

- `ROTARY_USE_CACHED_BOOTSTRAP_ONLY=1` launches directly into the cached/bootstrap fixture path for signed-in UI validation when a real backend session is not available.

## Launching a signed-in simulator session

1. Build and install Rotary on the simulator.
2. Export the debug auth variables in your shell.
3. Launch through the helper script:

```bash
cd /Users/jacoblopez/code/rotary-ios

export ROTARY_DEBUG_EMAIL="user@example.com"
export ROTARY_DEBUG_SESSION_TOKEN="eyJ..."
export ROTARY_USE_CACHED_BOOTSTRAP_ONLY="1"
./Scripts/launch-simulator-debug-auth.sh
```

By default the script targets the booted simulator and bundle id `com.theinterpretingapp.rotaryapp`.

## Custom target

```bash
ROTARY_SIM_DEVICE_ID="2A705662-6A4E-49A1-A5BF-19B1333C8279" \
ROTARY_BUNDLE_ID="com.theinterpretingapp.rotaryapp" \
./Scripts/launch-simulator-debug-auth.sh
```

## Notes

- These values are never committed to the repo.
- The script injects the variables with `SIMCTL_CHILD_*` so the app sees them as process environment variables.
- Use this only for simulator validation. Real-device sign-off still needs a real account session.
