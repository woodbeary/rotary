# TestFlight Release

Rotary uses the non-interactive [App Store Connect CLI](https://github.com/rudrankriyam/App-Store-Connect-CLI) workflow.

## One-time auth

If `asc auth status` shows no credentials, restore the API key with:

```bash
asc auth login \
  --name "rotary-appstore" \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --private-key "$ASC_PRIVATE_KEY_PATH"
```

Verify it:

```bash
asc auth status
```

## Release build

Use the Rotary project root:

```bash
cd /Users/jacoblopez/code/rotary-ios
```

Bump the build number:

```bash
asc xcode version bump --project Rotary.xcodeproj --scheme Rotary --type build
```

Archive and export:

```bash
asc xcode archive \
  --project Rotary.xcodeproj \
  --scheme Rotary \
  --configuration Release \
  --archive-path output/archive/Rotary.xcarchive

asc xcode export \
  --archive-path output/archive/Rotary.xcarchive \
  --export-options-plist ExportOptions.plist \
  --output-path output/export
```

Upload and wait for processing:

```bash
asc builds upload --app "$ASC_APP_ID" --ipa output/export/Rotary.ipa
asc builds wait --app "$ASC_APP_ID" --latest
```

List groups, then assign the processed build:

```bash
asc testflight groups list --app "$ASC_APP_ID"

asc builds add-groups \
  --app "$ASC_APP_ID" \
  --latest \
  --group "$ASC_GROUP_ID" \
  --submit \
  --confirm
```

## Release gates

Do not send external invites until all of these pass:

1. `xcodebuild`/simulator tests are green.
2. Signed-in simulator validation is complete.
3. Jacob’s iPhone has been validated for auth, voice registration, outbound calling, and push completion.
4. The uploaded build has finished App Store Connect processing.
