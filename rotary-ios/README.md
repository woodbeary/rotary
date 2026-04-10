# Rotary iOS

Native iPhone client for Rotary.

## Stack

- SwiftUI
- Clerk iOS SDK
- Twilio Voice iOS SDK
- PushKit + CallKit
- Sentry
- URLSession API client against `https://www.textjacob.com`

## Local setup

1. Install `xcodegen`.
2. Run `xcodegen generate`.
3. Open `Rotary.xcodeproj`.
4. Select a development team.
5. Run on a physical iPhone for voice features.

## Notes

- The initial bundle identifier intentionally reuses the previously configured app identity so Clerk/Twilio/APNS wiring can be brought up faster on day 1.
- Product-facing name is `Rotary`.
- Twilio Voice is pinned through the vendored `Vendor/TwilioVoice.xcframework` in this app target (not SwiftPM), currently `6.13.6`.
- Release workflow: [Docs/TestFlightRelease.md](/Users/jacoblopez/code/rotary-ios/Docs/TestFlightRelease.md)
- Signed-in simulator auth workflow: [Docs/SimulatorDebugAuth.md](/Users/jacoblopez/code/rotary-ios/Docs/SimulatorDebugAuth.md)
