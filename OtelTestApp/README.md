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

## What should *not* happen

The last section of the menu covers the automatic instrumentation this product deliberately omits,
which is what makes it safe to run alongside another observability SDK. None of these should
produce telemetry:

- **Network Request** — `URLSession` is not swizzled, so no HTTP span.
- **Push a Screen** — `UIViewController` is not swizzled, so no `screen_view` until you record one
  by hand.
- **Force Crash** — no crash handlers are installed, so no crash report on the next launch.

Taps are not captured either, so no `click` spans appear except from the Click button, which calls
`trackClick` directly.

What *is* still active, because it comes from the plugin rather than from instrumentation: flag
evaluation and identify hooks, `track` events recorded through `LDClient`, and session management
(this app rotates its session after 3 seconds in the background).
