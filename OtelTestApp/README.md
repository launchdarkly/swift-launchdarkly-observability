# OtelTestApp

A manual test app for the `LaunchDarklyOtel` product — the counterpart to `TestApp`, which
exercises the full `LaunchDarklyObservability` SDK.

`LaunchDarklyOtel` records only what an app explicitly asks it to, so this app is nothing but a
menu of `LDObserve` calls: logs, spans, metrics, errors, `track` events, screen views and clicks.
Its activity feed lists what each tap recorded, so you know what to look for in the backend.

The app imports `LaunchDarklyOtel` and nothing else from this repository. That is deliberate: if
the OTel-only product ever grows a dependency on the instrumentation package, this app stops
compiling.

## Setup

The app reads its LaunchDarkly credentials from `TestAppShared/Secrets.xcconfig`, which it shares
with `TestApp` and which is not checked in:

```bash
cp TestAppShared/Secrets.xcconfig.example TestAppShared/Secrets.xcconfig
```

Then fill in `mobileKey`. Open `OtelTestApp.xcodeproj` and run.

## What is and isn't active

Nothing is instrumented automatically: no HTTP spans, no `screen_view` on navigation, no `click`
spans on tap, and no crash reports. Everything this app records comes from a button that calls
`LDObserve` directly, which is what makes the product safe to run alongside another observability
SDK.

What *is* still active, because it comes from the plugin rather than from instrumentation: flag
evaluation and identify hooks, `track` events recorded through `LDClient`, and session management
(this app rotates its session after 3 seconds in the background).
