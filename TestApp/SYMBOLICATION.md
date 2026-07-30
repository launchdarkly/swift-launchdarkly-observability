# Apple Symbolication — generating & uploading `.dsymmap` for TestApp

This guide shows how to turn TestApp's **dSYM** debug info into compact symbol
maps (`.dsymmap`) and upload them, so crash/error stack traces show real
function names, `file:line`, and inlined call frames instead of raw addresses.

## How it works

1. An Xcode **Release** build produces a **dSYM** bundle (`TestApp.app.dSYM`).
   TestApp's Release configuration already emits one (`DEBUG_INFORMATION_FORMAT =
   dwarf-with-dsym`).
2. `ldcli symbols upload --type apple-dsym` reads the dSYM, and for **each
   architecture** (e.g. `arm64`, `x86_64`) compiles the DWARF into a compact
   `.dsymmap` symbol map keyed by that slice's **build UUID**.
3. Each map is uploaded to `_sym/apple/id/<UUID>.dsymmap`. At crash time the SDK
   reports the image UUID + instruction offset for each frame, and the backend
   loads the matching map to symbolicate.

You never generate or check in the `.dsymmap` yourself — `ldcli` builds it in
memory and uploads it. You only point it at the dSYM.

## Prerequisites

- **ldcli** with Apple support. Build from source:
  ```bash
  cd /path/to/ldcli
  CGO_ENABLED=1 go build -o ldcli .
  ```
- A LaunchDarkly **access token** and the **project key** for the environment
  receiving telemetry.

## Step 1 — build the exact app + dSYM once (Release)

Symbol maps are keyed strictly by **build UUID**. The one rule that matters for
an end-to-end test: the running app's per-image UUID must equal the UUID of the
dSYM you uploaded. The `.app` and its `.dSYM` come from the same link, so they
share UUIDs — **as long as you build once and then upload and run that same
product**. So build here once, to a fixed `-derivedDataPath`, and reuse that
artifact for both Step 2 (upload its dSYM) and Step 4 (run that same `.app`).

> Do **not** just press ⌘R afterwards. A Debug run usually leaves symbols in the
> binary (nothing to symbolicate) and, more importantly, relinks on each run, so
> its UUID drifts away from the map you uploaded.

A Release build emits both the `.app` and its `.dSYM` side by side.

### Simulator (fastest)
```bash
cd TestApp
xcodebuild build \
  -project TestApp.xcodeproj \
  -scheme TestApp \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/dd

APP="build/dd/Build/Products/Release-iphonesimulator/TestAppFruta.app"
```

### Physical device
```bash
cd TestApp
xcodebuild build \
  -project TestApp.xcodeproj -scheme TestApp -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/dd

APP="build/dd/Build/Products/Release-iphoneos/TestAppFruta.app"
```

The dSYM you upload in Step 2 is `"$APP.dSYM"`.

## Step 2 — upload with ldcli

Point `--path` at the `$APP.dSYM` you built in Step 1 (it can also be a single
`.dSYM` bundle, a directory tree containing several, or the inner DWARF file):

```bash
ldcli symbols upload \
  --type ios \
  --project <PROJECT_KEY> \
  --access-token <ACCESS_TOKEN> \
  --path "$APP.dSYM"
```

> `--type ios` is a synonym for the canonical `apple-dsym`. Any Apple platform
> acronym works: `ios`, `ipados`, `tvos`, `watchos`, `visionos`, `macos`, as well
> as `apple` and `dsym` (all case-insensitive).

### Optional — also upload your sources (`--include-sources`)

Symbolication alone gets you `MainMenuViewModel.swift:222`. Adding
`--include-sources` also uploads the source files the dSYM's debug info
references, so the errors page shows the **code around each frame** instead of
just the location:

```bash
ldcli symbols upload \
  --type ios \
  --project <PROJECT_KEY> \
  --access-token <ACCESS_TOKEN> \
  --path "$APP.dSYM" \
  --include-sources
```

```
Built symbol map for BD1993CF2B693D1290F66439459E4E63 (arm64, 10240 bytes)
Built source bundle for BD1993CF2B693D1290F66439459E4E63 (arm64, 37 files, 48512 bytes)
```

This packs the files into a `.srcbundle` uploaded next to the `.dsymmap` under
the same UUID, so it is matched to a build exactly as the symbol map is.

- **Off by default, because it stores your source code in LaunchDarkly.**
- Run it on the machine that built the app — files the dSYM names but that aren't
  on disk (SDK and system sources, or a dSYM copied from CI) are simply skipped.
- Only `.swift`, `.m`, `.mm`, `.c`, `.cpp`, `.cc`, `.h`, `.hh` and `.hpp` files
  are packed; individual files over 2 MiB and a bundle over 64 MiB are skipped.
- If no sources are found locally it says so and uploads the symbol map alone, so
  this flag can't break an upload that would otherwise work.

Frames that resolve to `<compiler-generated>` (optimizer-produced thunks,
outlined helpers, specialization glue) have no source line in DWARF at all, so
they show module + offset no matter what you upload.

Expected output:

```
Starting to upload apple-dsym symbols from build/dd/Build/Products/Release-iphonesimulator/TestAppFruta.app.dSYM
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
  --type ios \
  --project default \
  --access-token <STAGING_TOKEN> \
  --base-uri https://ld-stg.launchdarkly.com \
  --backend-url http://localhost:8082/private \
  --path "$APP.dSYM"
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
  --type ios \
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

## Step 4 — install & launch the *exact* binary you uploaded the dSYM for

Reuse the `$APP` you built in Step 1 — **do not rebuild** between uploading and
running, or the UUID drifts away from the map you uploaded. TestApp's bundle id
is `com.launchdarkly.TestApp`.

First confirm the app and its dSYM share the same UUIDs:

```bash
dwarfdump --uuid "$APP/TestAppFruta"
dwarfdump --uuid "$APP.dSYM/Contents/Resources/DWARF/TestAppFruta"
```

### Simulator (fastest)

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcrun simctl install booted "$APP"
xcrun simctl launch --console booted com.launchdarkly.TestApp
```

### Physical device (Xcode 15+, `devicectl`)

```bash
xcrun devicectl list devices                               # find your device UDID
xcrun devicectl device install app    --device <UDID> "$APP"
xcrun devicectl device process launch --device <UDID> com.launchdarkly.TestApp
```

Then tap an **Error dSYM** or **Crash** button. The `file:line` + inlined frames
come from the uploaded symbol map, so a plain simulator build is a fully valid
test.

## Verifying

Re-run the same dSYM upload as often as you like — maps are keyed by UUID and
overwrite cleanly. Confirm the build UUIDs you uploaded match the app you're
running:

```bash
dwarfdump --uuid "$APP.dSYM"
```

Those UUIDs (uppercased, no dashes) form the keys under
`_sym/apple/id/<UUID>.dsymmap`, and are what the SDK reports per frame at crash
time.
