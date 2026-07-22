# Apple Symbolication — generating & uploading `.ldsm` for TestApp

This guide shows how to turn TestApp's **dSYM** debug info into LaunchDarkly
symbol maps (`.ldsm`) and upload them, so crash/error stack traces show real
function names, `file:line`, and inlined call frames instead of raw addresses.

## How it works

1. An Xcode **Release** build produces a **dSYM** bundle (`TestApp.app.dSYM`).
   TestApp's Release configuration already emits one (`DEBUG_INFORMATION_FORMAT =
   dwarf-with-dsym`).
2. `ldcli symbols upload --type apple-dsym` reads the dSYM, and for **each
   architecture** (e.g. `arm64`, `x86_64`) compiles the DWARF into a compact
   `.ldsm` symbol map keyed by that slice's **build UUID**.
3. Each map is uploaded to `_sym/apple/id/<UUID>`. At crash time the SDK reports
   the image UUID + instruction offset for each frame, and the backend loads the
   matching map to symbolicate.

You never generate or check in the `.ldsm` yourself — `ldcli` builds it in
memory and uploads it. You only point it at the dSYM.

## Prerequisites

- **ldcli** with Apple support. Build from source:
  ```bash
  cd /path/to/ldcli
  CGO_ENABLED=1 go build -o ldcli .
  ```
- A LaunchDarkly **access token** and the **project key** for the environment
  receiving telemetry.

## Step 1 — produce the dSYM (Release)

### Option A: Xcode
Product ▸ Archive. The dSYM is inside the archive at
`…/TestApp.xcarchive/dSYMs/TestApp.app.dSYM`.

### Option B: command line
```bash
cd TestApp
xcodebuild archive \
  -project TestApp.xcodeproj \
  -scheme TestApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/TestApp.xcarchive
```
The dSYM is written to `build/TestApp.xcarchive/dSYMs/TestApp.app.dSYM`.

> A plain `xcodebuild build` in Release also produces the dSYM next to the app in
> `DerivedData/.../Build/Products/Release-iphoneos/TestApp.app.dSYM`.

## Step 2 — upload with ldcli

Point `--path` at the archive's `dSYMs` folder (it can also be a single
`.dSYM` bundle, a directory tree containing several, or the inner DWARF file):

```bash
ldcli symbols upload \
  --type apple-dsym \
  --project <PROJECT_KEY> \
  --access-token <ACCESS_TOKEN> \
  --path build/TestApp.xcarchive/dSYMs
```

Expected output:

```
Starting to upload apple-dsym symbols from build/TestApp.xcarchive/dSYMs
Built symbol map for BD1993CF2B693D1290F66439459E4E63 (arm64, 10240 bytes)
[LaunchDarkly] Uploaded symbol map BD1993CF2B693D1290F66439459E4E63 (arm64)
Successfully uploaded all symbols
```

### Local / self-hosted backend
When testing against a local observability backend, target the private GraphQL
endpoint and the matching control-plane base URI (use a token from that same
environment):

```bash
ldcli symbols upload \
  --type apple-dsym \
  --project default \
  --access-token <STAGING_TOKEN> \
  --base-uri https://ld-stg.launchdarkly.com \
  --backend-url http://localhost:8082/private \
  --path build/TestApp.xcarchive/dSYMs
```

## Step 3 (recommended) — upload automatically on every build

Add a **Run Script** build phase so symbol maps upload as part of archiving —
the same pattern Firebase Crashlytics, Sentry, and Bugsnag use. In Xcode:
select the **TestApp** target ▸ **Build Phases** ▸ **+ ▸ New Run Script Phase**,
place it after **Compile Sources**, and use:

```bash
# Only upload for Release builds that actually generate a dSYM.
if [ "${CONFIGURATION}" != "Release" ]; then
  echo "Skipping symbol upload for ${CONFIGURATION}"
  exit 0
fi

/usr/local/bin/ldcli symbols upload \
  --type apple-dsym \
  --project "$LD_PROJECT_KEY" \
  --access-token "$LD_ACCESS_TOKEN" \
  --path "${DWARF_DSYM_FOLDER_PATH}"
```

Notes:
- `${DWARF_DSYM_FOLDER_PATH}` is set by Xcode to the folder holding the built
  dSYM(s), so no path juggling is needed.
- Provide `LD_PROJECT_KEY` / `LD_ACCESS_TOKEN` via the scheme's environment,
  an `.xcconfig`, or your CI secrets — do not hard-code the token.
- Uncheck **"Based on dependency analysis"** so the phase always runs.

## Verifying

Re-run the same dSYM upload as often as you like — maps are keyed by UUID and
overwrite cleanly. Confirm the build UUIDs you uploaded match the app you're
running:

```bash
dwarfdump --uuid build/TestApp.xcarchive/dSYMs/TestApp.app.dSYM
```

Those UUIDs (uppercased, no dashes) are the keys under `_sym/apple/id/…`, and
are what the SDK reports per frame at crash time.
